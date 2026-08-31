import { InputHTMLAttributes, TextareaHTMLAttributes } from 'react';

type FormFieldProps = InputHTMLAttributes<HTMLInputElement> & {
  label: string;
};

type TextAreaFieldProps = TextareaHTMLAttributes<HTMLTextAreaElement> & {
  label: string;
};

export function FormField({ label, ...props }: FormFieldProps) {
  return (
    <label className="form-field">
      <span>{label}</span>
      <input {...props} />
    </label>
  );
}

export function TextAreaField({ label, ...props }: TextAreaFieldProps) {
  return (
    <label className="form-field">
      <span>{label}</span>
      <textarea {...props} />
    </label>
  );
}
