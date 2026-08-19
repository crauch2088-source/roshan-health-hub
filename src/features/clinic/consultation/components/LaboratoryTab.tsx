import { useState } from 'react';

interface LaboratoryTabProps {
  visitId: string;
}

export function LaboratoryTab({ visitId }: LaboratoryTabProps) {
  const [selectedTests, setSelectedTests] = useState<string[]>([]);
  const [notes, setNotes] = useState('');

  const availableTests = [
    'صورة دم كاملة (CBC)',
    'سكر الدم العشوائي (Random Blood Sugar)',
    'وظائف الكلى (Creatinine / Urea)',
    'وظائف الكبد (ALT / AST)',
    'تحليل البول الشامل (Urine Analysis)',
  ];

  const toggleTest = (test: string) => {
    setSelectedTests((prev) =>
      prev.includes(test) ? prev.filter((t) => t !== test) : [...prev, test]
    );
  };

  const handleSave = () => {
    alert(`تم طلب التحاليل بنجاح للزيارة: ${visitId}`);
  };

  return (
    <div className="space-y-6">
      <h2 className="text-lg font-semibold text-gray-900">التحاليل والفحوصات المخبرية</h2>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-3">اختر التحاليل المطلوبة:</label>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {availableTests.map((test) => {
            const isChecked = selectedTests.includes(test);
            return (
              <div
                key={test}
                onClick={() => toggleTest(test)}
                className={`p-3 rounded-lg border cursor-pointer transition flex items-center justify-between ${
                  isChecked ? 'border-primary bg-primary/5 text-primary font-medium' : 'border-gray-200 hover:bg-gray-50'
                }`}
              >
                <span>{test}</span>
                <input
                  type="checkbox"
                  checked={isChecked}
                  onChange={() => {}}
                  className="rounded text-primary focus:ring-primary"
                />
              </div>
            );
          })}
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">ملاحظات إضافية للمختبر</label>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          rows={2}
          className="w-full rounded-md border border-gray-300 p-3 text-sm focus:border-primary focus:outline-none"
          placeholder="أي تعليمات خاصة بالعينات..."
        />
      </div>

      <div className="flex justify-end">
        <button
          type="button"
          onClick={handleSave}
          className="px-4 py-2 bg-primary text-white rounded-md text-sm font-medium hover:bg-primary/90 transition"
        >
          حفظ وإرسال طلب التحاليل
        </button>
      </div>
    </div>
  );
}
