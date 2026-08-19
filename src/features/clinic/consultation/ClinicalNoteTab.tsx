import { useState } from 'react';
import { QUICK_COMPLAINTS } from '../options';

interface ClinicalNoteTabProps {
  visitId: string;
}

export function ClinicalNoteTab({ visitId }: ClinicalNoteTabProps) {
  const [complaint, setComplaint] = useState('');
  const [diagnosis, setDiagnosis] = useState('');

  const handleQuickSelect = (label: string) => {
    setComplaint((prev) => (prev ? `${prev}, ${label}` : label));
  };

  const handleSave = () => {
    // يمكن ربطها لاحقاً بـ Supabase أو الـ API الفعلي
    alert(`تم حفظ الملاحظات بنجاح للزيارة: ${visitId}`);
  };

  return (
    <div className="space-y-6">
      <h2 className="text-lg font-semibold text-gray-900">الملاحظات الإكلينيكية والفحص</h2>

      {/* الشكوى الرئيسية */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">الشكوى الرئيسية (Chief Complaint)</label>
        <textarea
          value={complaint}
          onChange={(e) => setComplaint(e.target.value)}
          rows={3}
          className="w-full rounded-md border border-gray-300 p-3 text-sm focus:border-primary focus:outline-none"
          placeholder="اكتب الشكوى الرئيسية أو اختر من القوائم السريعة أدناه..."
        />
        
        {/* أزرار الشكاوى السريعة */}
        <div className="flex flex-wrap gap-2 mt-2">
          {QUICK_COMPLAINTS.map((item) => (
            <button
              key={item.id}
              type="button"
              onClick={() => handleQuickSelect(item.label)}
              className="px-3 py-1 bg-gray-100 hover:bg-gray-200 text-gray-800 text-xs rounded-full transition"
            >
              + {item.label}
            </button>
          ))}
        </div>
      </div>

      {/* التشخيص */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">التشخيص (Diagnosis)</label>
        <input
          type="text"
          value={diagnosis}
          onChange={(e) => setDiagnosis(e.target.value)}
          className="w-full rounded-md border border-gray-300 p-3 text-sm focus:border-primary focus:outline-none"
          placeholder="أدخل التشخيص المبدئي أو النهائي..."
        />
      </div>

      {/* زر الحفظ */}
      <div className="flex justify-end">
        <button
          type="button"
          onClick={handleSave}
          className="px-4 py-2 bg-primary text-white rounded-md text-sm font-medium hover:bg-primary/90 transition"
        >
          حفظ الملاحظات
        </button>
      </div>
    </div>
  );
}
