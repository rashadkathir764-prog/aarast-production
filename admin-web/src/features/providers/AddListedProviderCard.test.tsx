import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../../platform/api/client';
import {
  AddListedProviderCard,
  listedProviderErrorMessage,
} from './AddListedProviderCard';
import * as providersApi from './api';

// V1 checklist 4.18: the back office lists a provider before its owner has
// an account; the owner claims it from the app with the same phone.

vi.mock('./api', () => ({ createListedProvider: vi.fn() }));

const cities = [{ id: 'city-1', nameAr: 'صنعاء' }] as never;
const categories = [{ id: 'category-1', nameAr: 'فنانون وزفة' }] as never;

function renderCard(onCreated = vi.fn()) {
  render(
    <MemoryRouter>
      <AddListedProviderCard
        cities={cities}
        categories={categories}
        onCreated={onCreated}
      />
    </MemoryRouter>,
  );
  return onCreated;
}

function fill(label: string, value: string) {
  fireEvent.change(screen.getByLabelText(label), { target: { value } });
}

describe('AddListedProviderCard', () => {
  beforeEach(() => vi.mocked(providersApi.createListedProvider).mockReset());

  it('sends the listing and tells the admin to add a service', async () => {
    vi.mocked(providersApi.createListedProvider).mockResolvedValue({
      id: 'provider-1',
      businessName: 'الفنان علي',
    } as never);
    const onCreated = renderCard();

    fill('اسم النشاط', 'الفنان علي');
    fill('رقم الجوال (رقم صاحب النشاط)', '777123456');
    fill('المدينة', 'city-1');
    fill('الفئة', 'category-1');
    fireEvent.click(screen.getByRole('button', { name: 'إضافة المزوّد' }));

    await waitFor(() => expect(onCreated).toHaveBeenCalled());
    expect(providersApi.createListedProvider).toHaveBeenCalledWith({
      businessName: 'الفنان علي',
      phone: '777123456',
      whatsapp: null,
      cityId: 'city-1',
      categoryId: 'category-1',
      address: null,
      description: null,
    });
    expect(screen.getByRole('status').textContent).toContain('أضف له خدمة');
  });

  it('explains a phone that another provider already uses', () => {
    expect(
      listedProviderErrorMessage(
        new ApiError('taken', 409, 'PROVIDER_PHONE_TAKEN'),
      ),
    ).toContain('مسجّل لمزوّد آخر');
    expect(listedProviderErrorMessage(new Error('تعذر الاتصال'))).toBe(
      'تعذر الاتصال',
    );
  });
});
