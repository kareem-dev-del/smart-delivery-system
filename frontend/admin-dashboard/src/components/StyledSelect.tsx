import type { ReactNode } from "react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/select";

const EMPTY_VALUE = "__smartdrop_empty_option__";

interface StyledSelectProps {
  value: string;
  onChange: (value: string) => void;
  options: Array<{ value: string; label: ReactNode; disabled?: boolean }>;
  ariaLabel: string;
  className?: string;
  disabled?: boolean;
  placeholder?: string;
}

export function StyledSelect({ value, onChange, options, ariaLabel, className = "", disabled, placeholder }: StyledSelectProps) {
  return (
    <Select
      value={value === "" ? EMPTY_VALUE : value}
      onValueChange={(nextValue) => onChange(nextValue === EMPTY_VALUE ? "" : nextValue)}
      disabled={disabled}
    >
      <SelectTrigger className={`app-select-trigger ${className}`} aria-label={ariaLabel}>
        <SelectValue placeholder={placeholder} />
      </SelectTrigger>
      <SelectContent className="app-select-content" position="popper" sideOffset={5} align="end">
        {options.map((option) => (
          <SelectItem
            key={option.value || EMPTY_VALUE}
            value={option.value || EMPTY_VALUE}
            disabled={option.disabled}
            className="app-select-item"
          >
            {option.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
