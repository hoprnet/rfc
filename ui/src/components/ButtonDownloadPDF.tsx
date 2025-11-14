import { forwardRef, Ref } from "react";
import styled from "@emotion/styled";
import MuiButton, { ButtonProps } from "@mui/material/Button";

const StyledButton = styled(MuiButton)<ButtonProps>`
  background: transparent;
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
  border: 1px solid white;
  margin-top: 20px;
`;

const Button = forwardRef((props: ButtonProps, ref: Ref<HTMLButtonElement>) => {
  return (
    <StyledButton variant="contained" {...props} ref={ref}>
      Download as PDF
    </StyledButton>
  );
});

Button.displayName = "ButtonDownloadPDF"; // Set the display name here

export default Button;
