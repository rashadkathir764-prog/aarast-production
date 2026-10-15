import { ChangeEvent, useState } from 'react';
import { ActionButton } from '../../design_system/ActionButton';
import { FormCard } from '../../design_system/FormCard';
import { listedProviderErrorMessage } from './AddListedProviderCard';
import {
  createListedProvider,
  type CityProjection,
  type ProviderCategoryProjection,
} from './api';
import {
  parseCsv,
  providerCsvTemplate,
  readProviderRows,
  type ProviderImportRow,
} from './providerCsv';

type ImportProvidersCardProps = {
  cities: CityProjection[];
  categories: ProviderCategoryProjection[];
  onImported: () => void | Promise<void>;
};

type RowOutcome = { line: number; ok: boolean; message: string };

/**
 * Imports providers from a CSV saved by Excel or Google Sheets (V1
 * checklist 4.22). The admin sees every row's problems before sending; each
 * valid row is created one by one through the audited single-listing
 * endpoint, so one refused row (a phone already listed) does not stop the
 * rest, and the result of every row is shown.
 */
export function ImportProvidersCard({
  cities,
  categories,
  onImported,
}: ImportProvidersCardProps) {
  const [rows, setRows] = useState<ProviderImportRow[]>([]);
  const [fileError, setFileError] = useState<string | null>(null);
  const [outcomes, setOutcomes] = useState<RowOutcome[]>([]);
  const [importing, setImporting] = useState(false);

  async function readFile(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    setOutcomes([]);
    setRows([]);
    setFileError(null);
    if (!file) return;
    const result = readProviderRows(parseCsv(await file.text()), cities, categories);
    setFileError(result.error);
    setRows(result.rows);
  }

  async function importRows() {
    setImporting(true);
    const results: RowOutcome[] = [];
    for (const row of rows) {
      if (!row.input) continue;
      try {
        await createListedProvider(row.input);
        results.push({ line: row.line, ok: true, message: `أُضيف «${row.businessName}»` });
      } catch (err) {
        results.push({ line: row.line, ok: false, message: listedProviderErrorMessage(err) });
      }
      setOutcomes([...results]);
    }
    setRows([]);
    setImporting(false);
    await onImported();
  }

  const valid = rows.filter((row) => row.input !== null).length;
  const invalid = rows.length - valid;
  const added = outcomes.filter((outcome) => outcome.ok).length;
  const templateHref = `data:text/csv;charset=utf-8,${encodeURIComponent(providerCsvTemplate())}`;

  return (
    <FormCard
      title="استيراد مزوّدين من ملف"
      subtitle="ملف CSV (احفظه من Excel بصيغة CSV UTF-8). كل صف يصبح مزوّدًا بلا حساب يستلمه صاحبه برقمه."
    >
      <div className="side-form">
        <a href={templateHref} download="aarast-providers-template.csv">
          تنزيل القالب
        </a>
        <label className="form-field">
          <span>ملف المزوّدين</span>
          <input type="file" accept=".csv,text/csv" onChange={readFile} disabled={importing} />
        </label>
        {fileError ? (
          <p className="inline-error" role="alert">
            {fileError}
          </p>
        ) : null}
        {rows.length > 0 ? (
          <>
            <p className="security-note" role="status">
              {valid} صف جاهز{invalid > 0 ? `، و${invalid} فيها مشاكل لن تُستورد` : ''}.
            </p>
            {invalid > 0 ? (
              <ul className="compact-list" aria-label="صفوف فيها مشاكل">
                {rows
                  .filter((row) => row.errors.length > 0)
                  .map((row) => (
                    <li key={row.line}>
                      الصف {row.line}: {row.errors.join('، ')}
                    </li>
                  ))}
              </ul>
            ) : null}
            <div className="form-actions">
              <ActionButton type="button" onClick={importRows} disabled={importing || valid === 0}>
                {importing ? 'جارٍ الاستيراد…' : `استيراد ${valid} مزوّد`}
              </ActionButton>
            </div>
          </>
        ) : null}
        {outcomes.length > 0 ? (
          <>
            <p className="security-note" role="status">
              أُضيف {added} من {outcomes.length}. أضف لكل مزوّد خدمة نشطة ليظهر في الدليل.
            </p>
            <ul className="compact-list" aria-label="نتيجة الاستيراد">
              {outcomes.map((outcome) => (
                <li key={outcome.line} className={outcome.ok ? undefined : 'inline-error'}>
                  الصف {outcome.line}: {outcome.message}
                </li>
              ))}
            </ul>
          </>
        ) : null}
      </div>
    </FormCard>
  );
}
