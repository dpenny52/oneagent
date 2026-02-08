"use client";

import { inputStyle, inputFocusCSS } from "../lib/theme";

/** Apply glow-border focus style to an input/textarea/select. */
export function applyFocus(
  e: React.FocusEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>,
) {
  const base = inputStyle();
  const cssStr = Object.entries(base)
    .map(
      ([k, v]) =>
        `${k.replace(/([A-Z])/g, "-$1").toLowerCase()}:${v}`,
    )
    .join(";");
  e.currentTarget.setAttribute("style", `${cssStr}; ${inputFocusCSS}`);
}

/** Remove focus glow, restoring the default input style. */
export function removeFocus(
  e: React.FocusEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>,
) {
  Object.assign(e.currentTarget.style, inputStyle());
}
