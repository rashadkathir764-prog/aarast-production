import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  createCategory,
  getCategories,
  getReferenceCatalog,
  getReferenceCatalogs,
  publishReferenceCatalogItem,
  updateReferenceCatalogItem,
  type ProviderCategory,
  type ReferenceCatalog,
  type ReferenceCatalogItem,
  type ReferenceCatalogRevision,
} from './api';
import { CategoriesPage } from './CategoriesPage';
import { ReferenceCatalogsPage } from './ReferenceCatalogsPage';

vi.mock('./api', () => ({
  getCategories: vi.fn(),
  createCategory: vi.fn(),
  updateCategory: vi.fn(),
  deleteCategory: vi.fn(),
  getReferenceCatalogs: vi.fn(),
  getReferenceCatalog: vi.fn(),
  createReferenceCatalogItem: vi.fn(),
  updateReferenceCatalogItem: vi.fn(),
  publishReferenceCatalogItem: vi.fn(),
  disableReferenceCatalogItem: vi.fn(),
}));

vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({ user: { id: 'admin-1', name: 'نادية', adminPermissions: ['CATALOG_READ', 'CATALOG_WRITE'] } }),
}));

afterEach(() => {
  vi.clearAllMocks();
});

function withRouter(element: JSX.Element) {
  return render(<MemoryRouter>{element}</MemoryRouter>);
}

const section = (nameAr: string, groom: boolean, bride: boolean): ProviderCategory => ({
  id: nameAr,
  nameAr,
  nameEn: null,
  slug: nameAr,
  icon: null,
  showForGroom: groom,
  showForBride: bride,
  isActive: true,
  sortOrder: 0,
});

describe('CategoriesPage (a08)', () => {
  it('shows each section on the groom and bride sides, or «ما يظهر»', async () => {
    vi.mocked(getCategories).mockResolvedValue([
      section('التصوير', true, true),
      section('المزمار والبرع', true, false),
    ]);
    withRouter(<CategoriesPage />);

    const row = (await screen.findByRole('button', { name: 'عدّل المزمار والبرع' })).closest('tr') as HTMLElement;
    const cells = within(row).getAllByRole('cell');
    expect(cells[1]).toHaveTextContent('المزمار والبرع');
    expect(cells[2]).toHaveTextContent('ما يظهر');
    expect(cells[3]).toHaveTextContent('نشط');
    expect(screen.queryByText('الطريقة المقترحة')).not.toBeInTheDocument();
    expect(screen.getByRole('navigation', { name: 'صفحات الكتالوج' })).toBeVisible();
  });

  it('shows the money item each side files the section under, «أخرى» in coral', async () => {
    vi.mocked(getCategories).mockResolvedValue([
      {
        ...section('التصوير', true, true),
        budgetItems: { groom: 'التصوير والفيديو', bride: 'التصوير', shared: 'التصوير' },
      },
      {
        ...section('تنظيف', true, true),
        budgetItems: { groom: null, bride: null, shared: null },
      },
    ]);
    withRouter(<CategoriesPage />);

    const photo = (await screen.findByRole('button', { name: 'عدّل التصوير' })).closest('tr') as HTMLElement;
    expect(within(photo).getAllByRole('cell')[1]).toHaveTextContent('في المال: التصوير والفيديو');
    expect(within(photo).getAllByRole('cell')[2]).toHaveTextContent('في المال: التصوير');
    const cleaning = screen.getByRole('button', { name: 'عدّل تنظيف' }).closest('tr') as HTMLElement;
    const warning = within(within(cleaning).getAllByRole('cell')[1]).getByText(
      'في المال: «أخرى»، ما فيه بند يناسبه',
    );
    expect(warning).toHaveClass('desk-ink--coral');
  });

  it('says after a save when the section lands in «أخرى»', async () => {
    vi.mocked(getCategories).mockResolvedValue([]);
    vi.mocked(createCategory).mockResolvedValue({
      ...section('تنظيف', true, true),
      budgetItems: { groom: null, bride: 'النظافة', shared: null },
    });
    withRouter(<CategoriesPage />);

    fireEvent.click(await screen.findByRole('button', { name: 'قسم جديد' }));
    const form = screen.getByRole('dialog', { name: 'قسم جديد' });
    fireEvent.change(within(form).getByLabelText('الاسم العربي'), { target: { value: 'تنظيف' } });
    fireEvent.click(within(form).getByRole('button', { name: 'احفظ' }));

    expect(
      await screen.findByText(
        'تكاليف «تنظيف» تروح «أخرى» عند العريس والخطة المشتركة: ما فيه بند في المال يناسب اسمه.',
      ),
    ).toBeVisible();
  });

  // RA-AD-16: the order went out as Number(x) || 0, so 1.5 or 2000000 reached
  // the server (a whole number within ±1,000,000) and came back as a bare
  // «راجع البيانات المدخلة». The field holds the server's rule, and the
  // browser stops the save on it, naming the field.
  it('holds the order to a whole number within the server’s bounds', async () => {
    vi.mocked(getCategories).mockResolvedValue([]);
    withRouter(<CategoriesPage />);
    fireEvent.click(await screen.findByRole('button', { name: 'قسم جديد' }));
    const order = within(screen.getByRole('dialog', { name: 'قسم جديد' })).getByLabelText('الترتيب') as HTMLInputElement;
    for (const value of ['1.5', '2000000', '-2000000']) {
      fireEvent.change(order, { target: { value } });
      expect(order.checkValidity()).toBe(false);
    }
    fireEvent.change(order, { target: { value: '12' } });
    expect(order.checkValidity()).toBe(true);
  });

  it('adds a section from «قسم جديد» and asks for one side at least', async () => {
    vi.mocked(getCategories).mockResolvedValue([]);
    vi.mocked(createCategory).mockResolvedValue(section('الكوش', true, true));
    withRouter(<CategoriesPage />);

    fireEvent.click(await screen.findByRole('button', { name: 'قسم جديد' }));
    const form = screen.getByRole('dialog', { name: 'قسم جديد' });
    fireEvent.change(within(form).getByLabelText('الاسم العربي'), { target: { value: 'الكوش' } });
    fireEvent.click(within(form).getByLabelText('يظهر عند العريس'));
    fireEvent.click(within(form).getByLabelText('يظهر عند العروسة'));
    expect(within(form).getByText('اختر مسار واحد على الأقل.')).toBeVisible();
    expect(within(form).getByRole('button', { name: 'احفظ' })).toBeDisabled();
    fireEvent.click(within(form).getByLabelText('يظهر عند العروسة'));
    fireEvent.click(within(form).getByRole('button', { name: 'احفظ' }));

    await waitFor(() =>
      expect(createCategory).toHaveBeenCalledWith(
        expect.objectContaining({ nameAr: 'الكوش', showForGroom: false, showForBride: true }),
      ),
    );
  });
});

function revision(input: Partial<ReferenceCatalogRevision>): ReferenceCatalogRevision {
  return {
    revision: 1,
    groupKey: 'contract',
    groupNameAr: 'العقد',
    groupSubtitleAr: null,
    nameAr: 'أوراق العقد عند الأمين الشرعي',
    nameEn: null,
    icon: 'file-check',
    sortOrder: 0,
    showForGroom: true,
    showForBride: false,
    showForCustomer: true,
    showForProvider: false,
    isRecommended: true,
    isActive: true,
    metadata: { daysBefore: 21 },
    createdAt: '2026-10-01T00:00:00.000Z',
    ...input,
  };
}

function item(id: string, current: ReferenceCatalogRevision, published: ReferenceCatalogRevision | null): ReferenceCatalogItem {
  return {
    id,
    key: id,
    currentRevision: current.revision,
    publishedRevision: published?.revision ?? 0,
    hasUnpublishedChanges: current.revision !== (published?.revision ?? 0),
    current,
    published,
    revisions: [],
    createdAt: '2026-10-01T00:00:00.000Z',
    updatedAt: '2026-10-01T00:00:00.000Z',
  };
}

const hall = revision({ nameAr: 'احجز القاعة', groupNameAr: 'المكان', showForBride: true, metadata: { daysBefore: 120 } });
const papersPublished = revision({});
const papersDraft = revision({ revision: 2, metadata: { daysBefore: 30, source: 'starter' } });

const tasks: ReferenceCatalog = {
  id: 'c1',
  key: 'tasks.starter',
  nameAr: 'قوالب المهام',
  description: null,
  version: 3,
  isActive: true,
  updatedAt: '2026-10-01T00:00:00.000Z',
  items: [item('hall', hall, hall), item('papers', papersDraft, papersPublished)],
};

describe('ReferenceCatalogsPage (a09)', () => {
  function renderCatalogs() {
    vi.mocked(getReferenceCatalogs).mockResolvedValue([
      { id: 'c1', key: 'tasks.starter', nameAr: 'x', description: null, version: 3, isActive: true, itemsCount: 2, publishedCount: 1, pendingCount: 1, updatedAt: '' },
      { id: 'c2', key: 'money.starter.categories', nameAr: 'y', description: null, version: 1, isActive: true, itemsCount: 0, publishedCount: 0, pendingCount: 0, updatedAt: '' },
    ]);
    vi.mocked(getReferenceCatalog).mockResolvedValue(tasks);
    withRouter(<ReferenceCatalogsPage />);
  }

  it('lists the tasks with days and audience, and reads the draft beside the published one', async () => {
    renderCatalogs();

    const hallRow = await screen.findByRole('row', { name: 'اقرأ احجز القاعة' });
    expect(hallRow).toHaveTextContent('120 يوم');
    expect(hallRow).toHaveTextContent('العريس والعروسة');
    expect(hallRow).toHaveTextContent('منشورة');
    const papersRow = screen.getByRole('row', { name: 'اقرأ أوراق العقد عند الأمين الشرعي' });
    expect(papersRow).toHaveTextContent('مسودة');
    expect(papersRow).toHaveClass('is-hi');

    expect(screen.getByRole('button', { name: 'قوالب المهام' })).toHaveAttribute('aria-pressed', 'true');
    expect(screen.getByRole('button', { name: 'تصنيفات الميزانية' })).toBeVisible();
    expect(screen.getByRole('heading', { name: 'أوراق العقد عند الأمين الشرعي · مسودة' })).toBeVisible();
    const compare = screen.getByRole('table', { name: 'المنشور والمسودة' });
    expect(compare).toHaveTextContent('قبل 21 يوم');
    expect(within(compare).getByText('قبل 30 يوم')).toHaveClass('is-changed');
    expect(screen.queryByRole('button', { name: 'ارجع للمنشور' })).not.toBeInTheDocument();
    expect(screen.getByText('النشر يوصل الخطط الجديدة بس، والخطط القائمة ما تتغير.')).toBeVisible();
  });

  // RA-AD-14: «أوقف» stops an item at once (a revision published inactive);
  // nothing turned it back on: the page never sent isActive and offered no
  // way to. «شغّل» does the reverse the same way: active, and published.
  it('turns a stopped item back on, at once like stopping it', async () => {
    const stopped = revision({ revision: 3, nameAr: 'تذكرة الفستان', isActive: false });
    vi.mocked(getReferenceCatalogs).mockResolvedValue([
      { id: 'c1', key: 'tasks.starter', nameAr: 'x', description: null, version: 3, isActive: true, itemsCount: 1, publishedCount: 1, pendingCount: 0, updatedAt: '' },
    ]);
    vi.mocked(getReferenceCatalog).mockResolvedValue({ ...tasks, items: [item('dress', stopped, stopped)] });
    vi.mocked(updateReferenceCatalogItem).mockResolvedValue(item('dress', { ...stopped, revision: 4, isActive: true }, stopped));
    vi.mocked(publishReferenceCatalogItem).mockResolvedValue(item('dress', { ...stopped, revision: 4, isActive: true }, { ...stopped, revision: 4, isActive: true }));
    withRouter(<ReferenceCatalogsPage />);

    fireEvent.click(await screen.findByRole('button', { name: 'عدّل' }));
    const form = screen.getByRole('dialog', { name: 'تعديل تذكرة الفستان' });
    expect(within(form).queryByRole('button', { name: 'أوقف' })).not.toBeInTheDocument();
    fireEvent.click(within(form).getByRole('button', { name: 'شغّل' }));
    fireEvent.click(await screen.findByRole('button', { name: 'شغّله' }));
    await waitFor(() =>
      expect(updateReferenceCatalogItem).toHaveBeenCalledWith('tasks.starter', 'dress', { isActive: true }),
    );
    await waitFor(() => expect(publishReferenceCatalogItem).toHaveBeenCalledWith('tasks.starter', 'dress'));
  });

  it('publishes the draft', async () => {
    vi.mocked(publishReferenceCatalogItem).mockResolvedValue(item('papers', papersDraft, papersDraft));
    renderCatalogs();

    fireEvent.click(await screen.findByRole('button', { name: 'انشر المسودة' }));
    await waitFor(() =>
      expect(publishReferenceCatalogItem).toHaveBeenCalledWith('tasks.starter', 'papers'),
    );
  });

  it('changes the days before the wedding as a draft, keeping the rest of the metadata', async () => {
    vi.mocked(updateReferenceCatalogItem).mockResolvedValue(item('papers', papersDraft, papersPublished));
    renderCatalogs();

    fireEvent.click(await screen.findByRole('button', { name: 'عدّل' }));
    const form = screen.getByRole('dialog', { name: 'تعديل أوراق العقد عند الأمين الشرعي' });
    fireEvent.change(within(form).getByLabelText('قبل العرس (أيام)'), { target: { value: '45' } });
    fireEvent.click(within(form).getByRole('button', { name: 'احفظ مسودة' }));

    await waitFor(() =>
      expect(updateReferenceCatalogItem).toHaveBeenCalledWith(
        'tasks.starter',
        'papers',
        expect.objectContaining({ metadata: { daysBefore: 45, source: 'starter' } }),
      ),
    );
  });

  it('files a task under a category, «تلقائي» leaving it to the app', async () => {
    vi.mocked(updateReferenceCatalogItem).mockResolvedValue(item('papers', papersDraft, papersPublished));
    renderCatalogs();

    fireEvent.click(await screen.findByRole('button', { name: 'عدّل' }));
    const form = screen.getByRole('dialog', { name: 'تعديل أوراق العقد عند الأمين الشرعي' });
    const category = within(form).getByLabelText('القسم');
    expect((category as HTMLSelectElement).value).toBe('');
    fireEvent.change(category, { target: { value: 'DOCUMENTS' } });
    fireEvent.click(within(form).getByRole('button', { name: 'احفظ مسودة' }));

    await waitFor(() =>
      expect(updateReferenceCatalogItem).toHaveBeenCalledWith(
        'tasks.starter',
        'papers',
        expect.objectContaining({
          metadata: { daysBefore: 30, source: 'starter', taskCategory: 'DOCUMENTS' },
        }),
      ),
    );
  });

  describe('the money catalog (D73)', () => {
    const photo = revision({
      nameAr: 'التصوير والفيديو',
      groupNameAr: 'مناسبة الرجال',
      metadata: { persona: 'GROOM', providerCategorySlugs: ['photography', 'retired-section'] },
    });
    const cleaning = revision({ nameAr: 'ترتيب البيت بعد العرس', groupNameAr: 'البيت', metadata: { persona: 'GROOM' } });
    const money: ReferenceCatalog = {
      ...tasks,
      id: 'c2',
      key: 'money.starter.categories',
      nameAr: 'تصنيفات الميزانية',
      items: [item('photo', photo, photo), item('cleaning', cleaning, cleaning)],
    };

    async function editMoneyItem(name: string) {
      vi.mocked(getReferenceCatalogs).mockResolvedValue([
        { id: 'c2', key: 'money.starter.categories', nameAr: 'y', description: null, version: 1, isActive: true, itemsCount: 2, publishedCount: 2, pendingCount: 0, updatedAt: '' },
      ]);
      vi.mocked(getReferenceCatalog).mockResolvedValue(money);
      vi.mocked(getCategories).mockResolvedValue([
        { ...section('التصوير', true, true), slug: 'photography' },
        { ...section('خدمات التنظيف', true, true), slug: 'cleaning' },
        { ...section('قسم موقوف', true, true), slug: 'stopped', isActive: false },
      ]);
      vi.mocked(updateReferenceCatalogItem).mockResolvedValue(item('cleaning', cleaning, cleaning));
      withRouter(<ReferenceCatalogsPage />);
      fireEvent.click(await screen.findByRole('row', { name: `اقرأ ${name}` }));
      fireEvent.click(screen.getByRole('button', { name: 'عدّل' }));
      return screen.getByRole('dialog', { name: `تعديل ${name}` });
    }

    it('links an item to provider sections, beside the rest of its metadata', async () => {
      const form = await editMoneyItem('ترتيب البيت بعد العرس');
      const sections = within(form).getByRole('group', { name: 'أقسام المزودين' });
      const cleaningBox = await within(sections).findByLabelText('خدمات التنظيف');
      expect(cleaningBox).not.toBeChecked();
      // Only the active sections are offered.
      expect(within(sections).queryByLabelText('قسم موقوف')).not.toBeInTheDocument();
      fireEvent.click(cleaningBox);
      fireEvent.click(within(form).getByRole('button', { name: 'احفظ مسودة' }));

      await waitFor(() =>
        expect(updateReferenceCatalogItem).toHaveBeenCalledWith(
          'money.starter.categories',
          'cleaning',
          expect.objectContaining({
            metadata: { persona: 'GROOM', providerCategorySlugs: ['cleaning'] },
          }),
        ),
      );
    });

    it('keeps a link it does not list, and drops the key when none is left', async () => {
      const form = await editMoneyItem('التصوير والفيديو');
      const photoBox = await within(form).findByLabelText('التصوير');
      expect(photoBox).toBeChecked();
      fireEvent.click(photoBox);
      fireEvent.click(within(form).getByRole('button', { name: 'احفظ مسودة' }));

      await waitFor(() =>
        expect(updateReferenceCatalogItem).toHaveBeenCalledWith(
          'money.starter.categories',
          'photo',
          expect.objectContaining({
            metadata: { persona: 'GROOM', providerCategorySlugs: ['retired-section'] },
          }),
        ),
      );
    });

    it('stores no link when no section is chosen', async () => {
      const form = await editMoneyItem('ترتيب البيت بعد العرس');
      await within(form).findByLabelText('خدمات التنظيف');
      fireEvent.click(within(form).getByRole('button', { name: 'احفظ مسودة' }));

      await waitFor(() =>
        expect(updateReferenceCatalogItem).toHaveBeenCalledWith(
          'money.starter.categories',
          'cleaning',
          expect.objectContaining({ metadata: { persona: 'GROOM' } }),
        ),
      );
    });
  });
});
