import { FormEvent } from 'react';

type SearchInputProps = {
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  placeholder: string;
  buttonLabel?: string;
};

export function SearchInput({
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
    <form className="search-input" onSubmit={submit}>
      <span className="search-input__icon" aria-hidden="true" />
      <input
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
      />
      <button className="button button--ghost" type="submit">
        {buttonLabel}
      </button>
    </form>
  );
}
