import { FormEvent, useState } from 'react';
import { Link } from 'react-router-dom';
import { DeskButton, DeskNote } from '../../design_system/Desk';
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

  // Inside a05's «أضف مزود بلا حساب» window, on the desk kit (D56); the
  // window carries the title.
  return (
    <form className="desk-form" onSubmit={submit}>
      <DeskNote>
        يظهر في الدليل بعد ما تضيف له خدمة شغّالة، ويستلمه صاحبه من التطبيق لما يسجّل بنفس الرقم.
      </DeskNote>
      <label className="desk-field">
        اسم النشاط
        {/* RA-AD-16: each box stops where AdminListedProviderDto does. */}
        <input
          value={businessName}
          maxLength={160}
          onChange={(event) => setBusinessName(event.target.value)}
          required
        />
      </label>
      <div className="desk-row">
        <label className="desk-field">
          رقم الجوال (رقم صاحب النشاط)
          <input
            dir="ltr"
            inputMode="tel"
            maxLength={32}
            value={phone}
            onChange={(event) => setPhone(event.target.value)}
            required
          />
        </label>
        <label className="desk-field">
          رقم واتساب (اختياري)
          <input
            dir="ltr"
            inputMode="tel"
            maxLength={32}
            value={whatsapp}
            onChange={(event) => setWhatsapp(event.target.value)}
          />
        </label>
      </div>
      <div className="desk-row">
        <label className="desk-field">
          المدينة
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
        <label className="desk-field">
          القسم
          <select
            value={categoryId}
            onChange={(event) => setCategoryId(event.target.value)}
            required
          >
            <option value="">اختر القسم</option>
            {categories.map((category) => (
              <option key={category.id} value={category.id}>
                {category.nameAr}
              </option>
            ))}
          </select>
        </label>
      </div>
      <label className="desk-field">
        العنوان (اختياري)
        <input value={address} maxLength={300} onChange={(event) => setAddress(event.target.value)} />
      </label>
      <label className="desk-field">
        نبذة (اختياري)
        <textarea
          rows={3}
          value={description}
          maxLength={4000}
          onChange={(event) => setDescription(event.target.value)}
        />
      </label>
      {error ? <DeskNote tone="coral">{error}</DeskNote> : null}
      {created ? (
        <p className="desk-note" role="status">
          أُضيف «{created.businessName}».{' '}
          <Link to="/services">أضف له خدمة</Link> ليظهر في الدليل.
        </p>
      ) : null}
      <div className="desk-dialog__actions">
        <DeskButton type="submit" disabled={saving}>
          إضافة المزوّد
        </DeskButton>
      </div>
    </form>
  );
}

export function listedProviderErrorMessage(error: unknown): string {
  return providerErrorMessage(error, 'تعذر إضافة المزوّد.');
}
