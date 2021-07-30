use crate::{new_rpc_client, Command, Error, Result};
use clap::value_t_or_exit;
use itertools::Itertools;
use mullvad_management_interface::{types::Timestamp, Code};
use mullvad_types::account::AccountToken;
use std::io::{self, Write};

pub struct Account;

#[mullvad_management_interface::async_trait]
impl Command for Account {
    fn name(&self) -> &'static str {
        "account"
    }

    fn clap_subcommand(&self) -> clap::App<'static, 'static> {
        clap::SubCommand::with_name(self.name())
            .about("Control and display information about your Mullvad account")
            .setting(clap::AppSettings::SubcommandRequiredElseHelp)
            .subcommand(
                clap::SubCommand::with_name("set")
                    .about("Change account")
                    .arg(
                        clap::Arg::with_name("token")
                            .help("The Mullvad account token to configure the client with")
                            .required(false),
                    ),
            )
            .subcommand(
                clap::SubCommand::with_name("get")
                    .about("Display information about the currently configured account"),
            )
            .subcommand(
                clap::SubCommand::with_name("unset")
                    .about("Removes the account number from the settings"),
            )
            .subcommand(
                clap::SubCommand::with_name("create")
                    .about("Creates a new account and sets it as the active one"),
            )
            .subcommand(
                clap::SubCommand::with_name("redeem")
                    .about("Redeems a voucher")
                    .arg(
                        clap::Arg::with_name("voucher")
                            .help("The Mullvad voucher code to be submitted")
                            .required(true),
                    ),
            )
    }

    async fn run(&self, matches: &clap::ArgMatches<'_>) -> Result<()> {
        if let Some(set_matches) = matches.subcommand_matches("set") {
            let mut token = match set_matches.value_of("token") {
                Some(token) => token.to_string(),
                None => {
                    let mut token = String::new();
                    io::stdout()
                        .write_all(b"Enter account token: ")
                        .expect("Failed to write to STDOUT");
                    let _ = io::stdout().flush();
                    io::stdin()
                        .read_line(&mut token)
                        .expect("Failed to read from STDIN");
                    token
                }
            };
            token = token.split_whitespace().join("").to_string();
            self.set(Some(token)).await
        } else if let Some(_matches) = matches.subcommand_matches("get") {
            self.get().await
        } else if let Some(_matches) = matches.subcommand_matches("unset") {
            self.set(None).await
        } else if let Some(_matches) = matches.subcommand_matches("create") {
            self.create().await
        } else if let Some(matches) = matches.subcommand_matches("redeem") {
            let voucher = value_t_or_exit!(matches.value_of("voucher"), String);
            self.redeem_voucher(voucher).await
        } else {
            unreachable!("No account command given");
        }
    }
}

impl Account {
    async fn set(&self, token: Option<AccountToken>) -> Result<()> {
        let mut rpc = new_rpc_client().await?;
        rpc.set_account(token.clone().unwrap_or_default()).await?;
        if let Some(token) = token {
            println!("Mullvad account \"{}\" set", token);
        } else {
            println!("Mullvad account removed");
        }
        Ok(())
    }

    async fn get(&self) -> Result<()> {
        let mut rpc = new_rpc_client().await?;
        let settings = rpc.get_settings(()).await?.into_inner();
        if settings.account_token != "" {
            println!("Mullvad account: {}", settings.account_token);
            let expiry = rpc
                .get_account_data(settings.account_token)
                .await
                .map_err(|error| Error::RpcFailedExt("Failed to fetch account data", error))?
                .into_inner();
            println!(
                "Expires at     : {}",
                Self::format_expiry(&expiry.expiry.unwrap())
            );
        } else {
            println!("No account configured");
        }
        Ok(())
    }

    async fn create(&self) -> Result<()> {
        let mut rpc = new_rpc_client().await?;
        rpc.create_new_account(()).await?;
        println!("New account created!");
        self.get().await
    }

    async fn redeem_voucher(&self, mut voucher: String) -> Result<()> {
        let mut rpc = new_rpc_client().await?;
        voucher.retain(|c| c.is_alphanumeric());

        match rpc.submit_voucher(voucher).await {
            Ok(submission) => {
                let submission = submission.into_inner();
                println!(
                    "Added {} to the account",
                    Self::format_duration(submission.seconds_added)
                );
                println!(
                    "New expiry date: {}",
                    Self::format_expiry(&submission.new_expiry.unwrap())
                );
                Ok(())
            }
            Err(err) => {
                match err.code() {
                    Code::NotFound | Code::ResourceExhausted => {
                        eprintln!("Failed to submit voucher: {}", err.message());
                    }
                    _ => return Err(Error::RpcFailed(err)),
                }
                std::process::exit(1);
            }
        }
    }

    fn format_duration(seconds: u64) -> String {
        let dur = chrono::Duration::seconds(seconds as i64);
        if dur.num_days() > 0 {
            format!("{} days", dur.num_days())
        } else if dur.num_hours() > 0 {
            format!("{} hours", dur.num_hours())
        } else if dur.num_minutes() > 0 {
            format!("{} minutes", dur.num_minutes())
        } else {
            format!("{} seconds", dur.num_seconds())
        }
    }

    fn format_expiry(expiry: &Timestamp) -> String {
        let ndt = chrono::NaiveDateTime::from_timestamp(expiry.seconds, expiry.nanos as u32);
        let utc = chrono::DateTime::<chrono::Utc>::from_utc(ndt, chrono::Utc);
        utc.with_timezone(&chrono::Local).to_string()
    }
}
