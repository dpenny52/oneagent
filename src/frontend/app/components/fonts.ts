import { Instrument_Serif, DM_Sans, Lora } from "next/font/google";

export const instrumentSerif = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  style: ["normal", "italic"],
  variable: "--font-instrument",
});

export const dmSans = DM_Sans({
  subsets: ["latin"],
  weight: ["300", "400", "500", "600"],
  variable: "--font-dm",
});

export const lora = Lora({
  subsets: ["latin"],
  weight: ["400", "500"],
  style: ["normal", "italic"],
  variable: "--font-lora",
});

/** CSS class string that applies all three font variables */
export const fontVars = `${instrumentSerif.variable} ${dmSans.variable} ${lora.variable}`;
