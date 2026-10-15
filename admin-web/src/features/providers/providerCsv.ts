import type {
  CityProjection,
  ListedProviderInput,
  ProviderCategoryProjection,
} from './api';

// Importing providers from a spreadsheet (V1 checklist 4.22). The file is
// read in the browser; every valid row becomes one listing through the
// same audited endpoint as the single form (4.18), so the server keeps
// every rule (phone format, duplicates, active city and category).

export const MAX_IMPORT_ROWS = 300;

/** The template's header row; English keys are accepted too. */
export const PROVIDER_CSV_HEADERS = [
  'اسم النشاط',
  'الجوال',
  'واتساب',
  'المدينة',
  'الفئة',
  'العنوان',
  'النبذة',
] as const;

type Field = keyof Omit<ListedProviderInput, 'cityId' | 'categoryId'> | 'city' | 'category';

const HEADER_FIELDS: Record<string, Field> = {
  'اسم النشاط': 'businessName',
  'الاسم': 'businessName',
  businessname: 'businessName',
  name: 'businessName',
  'الجوال': 'phone',
  'رقم الجوال': 'phone',
  phone: 'phone',
  'واتساب': 'whatsapp',
  whatsapp: 'whatsapp',
  'المدينة': 'city',
  city: 'city',
  'الفئة': 'category',
  category: 'category',
  'العنوان': 'address',
  address: 'address',
  'النبذة': 'description',
  'الوصف': 'description',
  description: 'description',
};

export type ProviderImportRow = {
  /** The spreadsheet row number (the header is row 1). */
  line: number;
  businessName: string;
  input: ListedProviderInput | null;
  errors: string[];
};

/** RFC 4180 CSV: quoted fields, doubled quotes, CRLF or LF, and Excel's UTF-8 BOM. */
export function parseCsv(text: string): string[][] {
  const source = text.replace(/^﻿/, '');
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  for (let index = 0; index < source.length; index += 1) {
    const char = source[index];
    if (quoted) {
      if (char === '"') {
        if (source[index + 1] === '"') {
          field += '"';
          index += 1;
        } else {
          quoted = false;
        }
      } else {
        field += char;
      }
    } else if (char === '"') {
      quoted = true;
    } else if (char === ',') {
      row.push(field);
      field = '';
    } else if (char === '\n' || char === '\r') {
      if (char === '\r' && source[index + 1] === '\n') index += 1;
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
    } else {
      field += char;
    }
  }
  if (field !== '' || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows.filter((cells) => cells.some((cell) => cell.trim() !== ''));
}

/** Arabic spellings people mix up, so "صنعاء" matches "صنعاء " and "الأمانة" matches "الامانة". */
export function normalizeArabicName(value: string): string {
  return value
    .trim()
    .replace(/\s+/g, ' ')
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/[ً-ْـ]/g, '')
    .toLowerCase();
}

/** The last nine digits identify a Yemeni mobile however it was typed. */
function phoneKey(value: string): string {
  return value.replace(/\D/g, '').slice(-9);
}

/**
 * Reads the sheet into listings: the header names the columns, city and
 * category are matched by name, and each row lists what is wrong with it.
 */
export function readProviderRows(
  table: string[][],
  cities: CityProjection[],
  categories: ProviderCategoryProjection[],
): { rows: ProviderImportRow[]; error: string | null } {
  if (table.length < 2) {
    return { rows: [], error: 'الملف فارغ. أضف صف العناوين ثم صفًا لكل مزوّد.' };
  }
  const columns = table[0].map(
    (header) => HEADER_FIELDS[header.trim().toLowerCase()] ?? HEADER_FIELDS[header.trim()],
  );
  for (const required of ['businessName', 'phone', 'city', 'category'] as const) {
    if (!columns.includes(required)) {
      return {
        rows: [],
        error: `عمود "${headerLabel(required)}" غير موجود. استخدم القالب.`,
      };
    }
  }
  if (table.length - 1 > MAX_IMPORT_ROWS) {
    return {
      rows: [],
      error: `الملف فيه ${table.length - 1} صفًا، والحد ${MAX_IMPORT_ROWS} في المرة الواحدة. قسّمه إلى ملفات أصغر.`,
    };
  }

  const cityByName = new Map(cities.map((city) => [normalizeArabicName(city.nameAr), city.id]));
  const categoryByName = new Map(
    categories.map((category) => [normalizeArabicName(category.nameAr), category.id]),
  );
  const seenPhones = new Map<string, number>();
  const rows = table.slice(1).map((cells, index): ProviderImportRow => {
    const line = index + 2;
    const value = (field: Field) => {
      const column = columns.indexOf(field);
      return column === -1 ? '' : (cells[column] ?? '').trim();
    };
    const errors: string[] = [];
    const businessName = value('businessName');
    const phone = value('phone');
    const cityName = value('city');
    const categoryName = value('category');
    if (!businessName) errors.push('اسم النشاط فارغ');
    if (!phone) {
      errors.push('رقم الجوال فارغ');
    } else {
      const key = phoneKey(phone);
      const firstLine = seenPhones.get(key);
      if (firstLine !== undefined) errors.push(`الرقم مكرر في الصف ${firstLine}`);
      else seenPhones.set(key, line);
    }
    const cityId = cityByName.get(normalizeArabicName(cityName));
    if (!cityId) errors.push(cityName ? `المدينة "${cityName}" غير موجودة` : 'المدينة فارغة');
    const categoryId = categoryByName.get(normalizeArabicName(categoryName));
    if (!categoryId) {
      errors.push(categoryName ? `الفئة "${categoryName}" غير موجودة` : 'الفئة فارغة');
    }
    return {
      line,
      businessName,
      errors,
      input:
        errors.length === 0
          ? {
              businessName,
              phone,
              whatsapp: value('whatsapp') || null,
              cityId: cityId!,
              categoryId: categoryId!,
              address: value('address') || null,
              description: value('description') || null,
            }
          : null,
    };
  });
  return { rows, error: null };
}

function headerLabel(field: Field): string {
  return {
    businessName: 'اسم النشاط',
    phone: 'الجوال',
    city: 'المدينة',
    category: 'الفئة',
  }[field as 'businessName' | 'phone' | 'city' | 'category'];
}

/** The template an admin downloads: the header row and one example. */
export function providerCsvTemplate(): string {
  const example = ['الفنان علي للزفة', '777123456', '777123456', 'صنعاء', 'فنانون وزفة', 'شارع حدة', ''];
  return `﻿${PROVIDER_CSV_HEADERS.join(',')}\r\n${example.join(',')}\r\n`;
}
