import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../../platform/api/client';
import { ImportProvidersCard } from './ImportProvidersCard';
import * as providersApi from './api';

// V1 checklist 4.22: a spreadsheet of providers becomes listings, row by
// row, and the admin sees what happened to every row.

vi.mock('./api', () => ({ createListedProvider: vi.fn() }));

const cities = [{ id: 'city-sanaa', nameAr: 'صنعاء' }] as never;
const categories = [{ id: 'cat-zaffa', nameAr: 'فنانون وزفة' }] as never;
const csv = [
  'اسم النشاط,الجوال,واتساب,المدينة,الفئة,العنوان,النبذة',
  'الفنان علي,777123456,,صنعاء,فنانون وزفة,,',
  'قاعة النور,777999888,,صنعاء,فنانون وزفة,,',
  'بلا مدينة,777000111,,عدن,فنانون وزفة,,',
].join('\n');

describe('ImportProvidersCard', () => {
  beforeEach(() => vi.mocked(providersApi.createListedProvider).mockReset());

  it('previews problems, imports valid rows and reports each one', async () => {
    vi.mocked(providersApi.createListedProvider)
      .mockResolvedValueOnce({ id: 'p1' } as never)
      .mockRejectedValueOnce(new ApiError('taken', 409, 'PROVIDER_PHONE_TAKEN'));
    const onImported = vi.fn();
    render(
      <ImportProvidersCard cities={cities} categories={categories} onImported={onImported} />,
    );

    const file = new File([csv], 'providers.csv', { type: 'text/csv' });
    fireEvent.change(screen.getByLabelText('ملف المزوّدين'), { target: { files: [file] } });

    expect(await screen.findByText(/2 صف جاهز، و1 فيها مشاكل/)).toBeTruthy();
    expect(screen.getByText(/الصف 4: المدينة "عدن" غير موجودة/)).toBeTruthy();

    fireEvent.click(screen.getByRole('button', { name: 'استيراد 2 مزوّد' }));

    await waitFor(() => expect(onImported).toHaveBeenCalled());
    expect(providersApi.createListedProvider).toHaveBeenCalledTimes(2);
    expect(screen.getByText(/أُضيف 1 من 2/)).toBeTruthy();
    expect(screen.getByText(/الصف 2: أُضيف «الفنان علي»/)).toBeTruthy();
    expect(screen.getByText(/الصف 3: هذا الرقم مسجّل لمزوّد آخر/)).toBeTruthy();
  });
});
