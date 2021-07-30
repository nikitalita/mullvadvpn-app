# Mullvad VPN iOS app

This is the iOS version of the Mullvad VPN app. The app can be found on the Apple [App Store].

All releases have signed git tags on the format `ios/<version>`. For changes between each
release, see the [changelog].

[App Store]: https://apps.apple.com/us/app/mullvad-vpn/id1488466513
[changelog]: CHANGELOG.md


## Screenshots for AppStore

The process of taking AppStore screenshots is automated using a UI Testing bundle and Snapshot tool,
a part of Fastlane tools.

### Configuration

The screenshot script uses the real account token to log in, which is provided via Xcode build 
configuration.

1. Create the build configuration using a template file:
   
   ```
   cp ios/Configurations/Screenshots.xcconfig.template ios/Configurations/Screenshots.xcconfig
   ```

1. Edit the configuration file and put your account token without quotes:
   
   ```
   vim ios/Configurations/Screenshots.xcconfig
   ```

### Prerequisitives

1. Make sure you have [rvm](https://rvm.io) installed.
1. Install Ruby 2.5.1 or later using `rvm install <VERSION>`.
1. Install necessary third-party ruby gems:
   
   ```
   cd ios
   bundle install
   ```

### Take screenshots

Run the following command to take screenshots:

```
cd ios
bundle exec fastlane snapshot
```

Once done all screenshots should be saved under `ios/Screenshots` folder.

### Localizations

#### Update localizations from source

Run the following command in terminal:

```
python3 update_localizations.py
```

#### Locking Python dependencies

1. Freeze dependencies:

```
pip3 freeze -r requirements.txt
```

and save the output into `requirements.txt`.


2. Hash them with `hashin` tool:

```
hashin --python 3.7 --verbose --update-all
```