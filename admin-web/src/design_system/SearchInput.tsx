import { FormEvent } from 'react';

type SearchInputProps = {
  label: string;
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  placeholder: string;
  buttonLabel?: string;
};

export function SearchInput({
  label,
  value,
  onChange,
  onSubmit,
  placeholder,
  buttonLabel = 'بحث',
}: SearchInputProps) {
  function submit(event: FormEvent) {
    event.preventDefault();
    onSubmit();
  }

  return (
    <form
      className="search-input"
      role="search"
      aria-label={label}
      onSubmit={submit}
    >
      <label className="search-input__field">
        <span>{label}</span>
        <input
          type="search"
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder={placeholder}
        />
      </label>
      <button className="button button--ghost" type="submit">
        {buttonLabel}
      </button>
    </form>
  );
}
