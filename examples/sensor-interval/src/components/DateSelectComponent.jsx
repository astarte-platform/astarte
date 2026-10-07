import React, { forwardRef } from "react";
import DatePicker from "react-datepicker";
import "react-datepicker/dist/react-datepicker.css";
const DateSelect = ({
  startDate,
  endDate,
  placeholder,
  disabled,
  handleChange,
}) => {
  const CustomInput = forwardRef((props, ref) => {
    const value =
      startDate && endDate
        ? `${startDate.toLocaleDateString()} - ${endDate.toLocaleDateString()}`
        : "";
    return (
      <input
        onClick={props.onClick}
        ref={ref}
        value={value}
        placeholder={placeholder}
        readOnly
      />
    );
  });

  return (
    <DatePicker
      disabled={disabled}
      monthsShown={2}
      onChange={handleChange}
      startDate={startDate}
      endDate={endDate}
      customInput={<CustomInput />}
      selectsRange
    />
  );
};

export default DateSelect;
