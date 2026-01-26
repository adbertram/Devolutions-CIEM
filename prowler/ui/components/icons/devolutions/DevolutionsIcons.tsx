import React from "react";

import { IconSvgProps } from "../../../types/index";

export const DevolutionsExtended: React.FC<IconSvgProps> = ({
  size,
  width = 216,
  height,
  ...props
}) => {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 280 50"
      fill="none"
      height={size || height}
      width={size || width}
      {...props}
    >
      {/* Devolutions "D" Logo */}
      <path
        d="M5 5h20c11.046 0 20 8.954 20 20s-8.954 20-20 20H5V5z"
        fill="#3b82f6"
      />
      <path
        d="M12 12h13c7.18 0 13 5.82 13 13s-5.82 13-13 13H12V12z"
        fill="#1e3a5f"
      />
      {/* "CIEM" Text */}
      <text
        x="55"
        y="35"
        fontFamily="system-ui, -apple-system, sans-serif"
        fontSize="28"
        fontWeight="600"
        className="fill-slate-900 dark:fill-white"
        fill="currentColor"
      >
        Devolutions CIEM
      </text>
    </svg>
  );
};

export const DevolutionsShort: React.FC<IconSvgProps> = ({
  size,
  width = 30,
  height,
  ...props
}) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 50 50"
    fill="none"
    height={size || height}
    width={size || width}
    {...props}
  >
    {/* Devolutions "D" Logo - Shield Shape */}
    <path
      d="M5 5h20c11.046 0 20 8.954 20 20s-8.954 20-20 20H5V5z"
      fill="#3b82f6"
    />
    <path
      d="M12 12h13c7.18 0 13 5.82 13 13s-5.82 13-13 13H12V12z"
      fill="#1e3a5f"
    />
  </svg>
);
