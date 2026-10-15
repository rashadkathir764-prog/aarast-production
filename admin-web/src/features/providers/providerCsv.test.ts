import { describe, expect, it } from 'vitest';
import {
  MAX_IMPORT_ROWS,
  normalizeArabicName,
  parseCsv,
  providerCsvTemplate,
  readProviderRows,
} from './providerCsv';

// V1 checklist 4.22: providers imported from a spreadsheet.

const cities = [{ id: 'city-sanaa', nameAr: 'صنعاء' }] as never;
const categories = [{ id: 'cat-zaffa', nameAr: 'فنانون وزفة' }] as never;
const header = 'اسم النشاط,الجوال,واتساب,المدينة,الفئة,العنوان,النبذة';

describe('parseCsv', () => {
  it('reads quotes, commas inside quotes, CRLF and the Excel BOM', () => {
    expect(parseCsv('﻿a,"b, c","say ""hi"""\r\n1,2,3\r\n\r\n')).toEqual([
      ['a', 'b, c', 'say "hi"'],
      ['1', '2', '3'],
    ]);
  });

  it('keeps a last row without a newline', () => {
    expect(parseCsv('a,b\nc,d')).toEqual([
      ['a', 'b'],
      ['c', 'd'],
    ]);
  });
});

describe('readProviderRows', () => {
  it('turns each valid row into a listing, matching names loosely', () => {
    const { rows, error } = readProviderRows(
      parseCsv(`${header}\nالفنان علي,777123456,,صنعاء ,فنانون  وزفة,حدة,`),
      cities,
      categories,
    );
    expect(error).toBeNull();
    expect(rows).toEqual([
      {
        line: 2,
        businessName: 'الفنان علي',
        errors: [],
        input: {
          businessName: 'الفنان علي',
          phone: '777123456',
          whatsapp: null,
          cityId: 'city-sanaa',
          categoryId: 'cat-zaffa',
          address: 'حدة',
          description: null,
        },
      },
    ]);
  });

  it('lists what is wrong with each row, including a repeated phone', () => {
    const { rows } = readProviderRows(
      parseCsv(
        `${header}\nأ,777123456,,صنعاء,فنانون وزفة,,\nب,+967777123456,,عدن,قاعات,,\n,,,,,,x`,
      ),
      cities,
      categories,
    );
    expect(rows[0].errors).toEqual([]);
    expect(rows[1].input).toBeNull();
    expect(rows[1].errors).toEqual([
      'الرقم مكرر في الصف 2',
      'المدينة "عدن" غير موجودة',
      'الفئة "قاعات" غير موجودة',
    ]);
    expect(rows[2].errors).toContain('اسم النشاط فارغ');
  });

  it('refuses a sheet without the required columns or with too many rows', () => {
    expect(readProviderRows(parseCsv('name,phone\nx,1'), cities, categories).error).toContain(
      'المدينة',
    );
    const many = [header, ...Array.from({ length: MAX_IMPORT_ROWS + 1 }, () => 'a,1,,صنعاء,فنانون وزفة,,')];
    expect(readProviderRows(parseCsv(many.join('\n')), cities, categories).error).toContain(
      'الحد',
    );
  });

  it('accepts its own template', () => {
    const { rows, error } = readProviderRows(parseCsv(providerCsvTemplate()), cities, categories);
    expect(error).toBeNull();
    expect(rows[0].errors).toEqual([]);
  });

  it('normalizes the Arabic spellings people mix up', () => {
    expect(normalizeArabicName(' الأمانة ')).toBe(normalizeArabicName('الامانه'));
  });
});
