import React from 'react';
import styled from 'styled-components';
import { colors, supportEmail } from '../../config.json';
import { messages } from '../../shared/gettext';
import log from '../../shared/logging';
import PlatformWindowContainer from '../containers/PlatformWindowContainer';
import { sourceSansPro } from './common-styles';
import ImageView from './ImageView';
import { Container, Layout } from './Layout';

interface IProps {
  children?: React.ReactNode;
}

interface IState {
  hasError: boolean;
}

const StyledContainer = styled(Container)({
  flex: 1,
  flexDirection: 'column',
  alignItems: 'center',
  justifyContent: 'center',
  backgroundColor: colors.blue,
});

const Title = styled.h1({
  ...sourceSansPro,
  fontSize: '26px',
  lineHeight: '30px',
  color: colors.white60,
  marginBottom: '4px',
});

const Subtitle = styled.span({
  fontFamily: 'Open Sans',
  fontSize: '14px',
  lineHeight: '20px',
  color: colors.white40,
  marginHorizontal: '22px',
  textAlign: 'center',
});

const Email = styled.span({
  fontWeight: 900,
});

const Logo = styled(ImageView)({
  marginBottom: '5px',
});

export default class ErrorBoundary extends React.Component<IProps, IState> {
  public state = { hasError: false };

  public componentDidCatch(error: Error, info: React.ErrorInfo) {
    this.setState({ hasError: true });

    log.error(
      `The error boundary caught an error: ${error.message}\nError stack: ${
        error.stack || 'Not available'
      }\nComponent stack: ${info.componentStack}`,
    );
  }

  public render() {
    if (this.state.hasError) {
      const reachBackMessage: React.ReactNodeArray =
        // TRANSLATORS: The message displayed to the user in case of critical error in the GUI
        // TRANSLATORS: Available placeholders:
        // TRANSLATORS: %(email)s - support email
        messages
          .pgettext('error-boundary-view', 'Something went wrong. Please contact us at %(email)s')
          .split('%(email)s', 2);
      reachBackMessage.splice(1, 0, <Email>{supportEmail}</Email>);

      return (
        <PlatformWindowContainer>
          <Layout>
            <StyledContainer>
              <Logo height={106} width={106} source="logo-icon" />
              <Title>MULLVAD VPN</Title>
              <Subtitle role="alert">{reachBackMessage}</Subtitle>
            </StyledContainer>
          </Layout>
        </PlatformWindowContainer>
      );
    } else {
      return this.props.children;
    }
  }
}
