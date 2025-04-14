import { forwardRef, Ref } from 'react';
import styled from '@emotion/styled';
import MuiButton, { ButtonProps } from '@mui/material/Button';

type StyledButtonProps = ButtonProps & {
  imageOnly?: boolean;
  size70?: boolean;
  standardWidth?: boolean;
  fade?: boolean;
  pending?: boolean;
  nofade?: boolean;
  outlined?: boolean;
  target?: string;
};

const StyledButton = styled(MuiButton)<StyledButtonProps>`
  background: linear-gradient(#000050, #0000b4);
  text-align: center;
  text-transform: none;
  font-style: normal;
  font-weight: 500;
  font-size: 18px;
  border-radius: 20px;
  letter-spacing: 0.25px;
  line-height: 1.5;
  height: unset;
    font-family: "Inconsolata", monospace;
`;


const Button = forwardRef((props: StyledButtonProps, ref: Ref<HTMLButtonElement>) => {
  return (
    <StyledButton
      variant="contained"
      {...props}
      ref={ref}
    >
      {props.children}
    </StyledButton>
  );
});

Button.displayName = 'Button'; // Set the display name here

export default Button;
