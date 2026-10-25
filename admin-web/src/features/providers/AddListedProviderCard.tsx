import { FormEvent, useState } from 'react';
import { Link } from 'react-router-dom';
import { ActionButton } from '../../design_system/ActionButton';
import { FormCard } from '../../design_system/FormCard';
import { FormField, TextAreaField } from '../../design_system/FormField';
import { providerErrorMessage } from './providerHelpers';
import {
  createListedProvider,
  type CityProjection,
  type ProviderApplication,
  type ProviderCategoryProjection,
} from './api';

type AddListedProviderCardProps = {
  cities: CityProjection[];
  categories: ProviderCategoryProjection[];
  onCreated: () => void | Promise<void>;
};

/**
 * Lists a provider who has no account yet (V1 checklist 4.18). The listing
 * is active at once; its owner claims it from the app by signing in with the
 * same phone. Until then it takes no quote requests, only calls and WhatsApp.
 */
export function AddListedProviderCard({
  cities,
  categories,
  onCreated,
}: AddListedProviderCardProps) {
  const [businessName, setBusinessName] = useState('');
  const [phone, setPhone] = useState('');
  const [whatsapp, setWhatsapp] = useState('');
  const [cityId, setCityId] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [address, setAddress] = useState('');
  const [description, setDescription] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [created, setCreated] = useState<ProviderApplication | null>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setSaving(true);
    try {
      const provider = await createListedProvider({
        businessName,
        phone,
        whatsapp: whatsapp || null,
        cityId,
        categoryId,
        address: address || null,
        description: description || null,
      });
      setCreated(provider);
      setBusinessName('');
      setPhone('');
      setWhatsapp('');
      setAddress('');
      setDescription('');
      await onCreated();
    } catch (err) {
      setError(listedProviderErrorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <FormCard
      title="إضافة مزوّد بلا حساب"
      subtitle="يظهر في الدليل بعد إضافة خدمة نشطة له، ويستلمه صاحبه من التطبيق حين يسجّل بنفس الرقم."
    >
      <form className="side-form" onSubmit={submit}>
        <FormField
          label="اسم النشاط"
          value={businessName}
          onChange={(event) => setBusinessName(event.target.value)}
          required
        />
        <FormField
          label="رقم الجوال (رقم صاحب النشاط)"
          dir="ltr"
          inputMode="tel"
          value={phone}
          onChange={(event) => setPhone(event.target.value)}
          required
        />
        <FormField
          label="رقم واتساب (اختياري)"
          dir="ltr"
          inputMode="tel"
          value={whatsapp}
          onChange={(event) => setWhatsapp(event.target.value)}
        />
        <label className="form-field">
          <span>المدينة</span>
          <select
            value={cityId}
            onChange={(event) => setCityId(event.target.value)}
            required
          >
            <option value="">اختر المدينة</option>
            {cities.map((city) => (
              <option key={city.id} value={city.id}>
                {city.nameAr}
              </option>
            ))}
          </select>
        </label>
        <label className="form-field">
          <span>الفئة</span>
          <select
            value={categoryId}
            onChange={(event) => setCategoryId(event.target.value)}
            required
          >
            <option value="">اختر الفئة</option>
            {categories.map((category) => (
              <option key={category.id} value={category.id}>
                {category.nameAr}
              </option>
            ))}
          </select>
        </label>
        <FormField
          label="العنوان (اختياري)"
          value={address}
          onChange={(event) => setAddress(event.target.value)}
        />
        <TextAreaField
          label="نبذة (اختياري)"
          value={description}
          onChange={(event) => setDescription(event.target.value)}
        />
        {error ? (
          <p className="inline-error" role="alert">
            {error}
          </p>
        ) : null}
        {created ? (
          <p className="security-note" role="status">
            أُضيف «{created.businessName}».{' '}
            <Link to="/services">أضف له خدمة</Link> ليظهر في الدليل.
          </p>
        ) : null}
        <div className="form-actions">
          <ActionButton type="submit" disabled={saving}>
            {saving ? 'جارٍ الإضافة…' : 'إضافة المزوّد'}
          </ActionButton>
        </div>
      </form>
    </FormCard>
  );
}

export function listedProviderErrorMessage(error: unknown): string {
  return providerErrorMessage(error, 'تعذر إضافة المزوّد.');
}
