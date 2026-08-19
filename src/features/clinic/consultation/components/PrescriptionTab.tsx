import { useState } from 'react';
import { DOSES, FREQUENCIES, DURATIONS } from '../options';

interface PrescriptionTabProps {
  visitId: string;
}

interface MedicationItem {
  id: string;
  name: string;
  dose: string;
  frequency: string;
  duration: string;
}

export function PrescriptionTab({ visitId }: PrescriptionTabProps) {
  const [medName, setMedName] = useState('');
  const [dose, setDose] = useState(DOSES[0]);
  const [frequency, setFrequency] = useState(FREQUENCIES[0]);
  const [duration, setDuration] = useState(DURATIONS[0]);
  const [medications, setMedications] = useState<MedicationItem[]>([]);

  const handleAddMedication = () => {
    if (!medName.trim()) return;
    const newItem: MedicationItem = {
      id: Date.now().toString(),
      name: medName,
      dose,
      frequency,
      duration,
    };
    setMedications([...medications, newItem]);
    setMedName('');
  };

  const handleRemove = (id: string) => {
    setMedications(medications.filter((m) => m.id !== id));
  };

  const handleSave = () => {
    alert(`تم حفظ الروشتة والأدوية بنجاح للزيارة: ${visitId}`);
  };

  return (
    <div className="space-y-6">
      <h2 className="text-lg font-semibold text-gray-900">الروشتة والوصفات الطبية</h2>

      {/* نموذج إضافة دواء */}
      <div className="p-4 bg-gray-50 rounded-lg border border-gray-200 space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">اسم الدواء</label>
          <input
            type="text"
            value={medName}
            onChange={(e) => setMedName(e.target.value)}
            className="w-full rounded-md border border-gray-300 p-2.5 text-sm bg-white"
            placeholder="مثال: Paracetamol"
          />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">الجرعة</label>
            <select
              value={dose}
              onChange={(e) => setDose(e.target.value)}
              className="w-full rounded-md border border-gray-300 p-2 text-sm bg-white"
            >
              {DOSES.map((d) => (
                <option key={d} value={d}>{d}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">التكرار</label>
            <select
              value={frequency}
              onChange={(e) => setFrequency(e.target.value)}
              className="w-full rounded-md border border-gray-300 p-2 text-sm bg-white"
            >
              {FREQUENCIES.map((f) => (
                <option key={f} value={f}>{f}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">المدة</label>
            <select
              value={duration}
              onChange={(e) => setDuration(e.target.value)}
              className="w-full rounded-md border border-gray-300 p-2 text-sm bg-white"
            >
              {DURATIONS.map((dur) => (
                <option key={dur} value={dur}>{dur}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="flex justify-end">
          <button
            type="button"
            onClick={handleAddMedication}
            className="px-3 py-1.5 bg-gray-800 text-white rounded text-xs font-medium hover:bg-gray-700 transition"
          >
            + إضافة دواء للقائمة
          </button>
        </div>
      </div>

      {/* قائمة الأدوية المضافة */}
      {medications.length > 0 && (
        <div className="border rounded-lg overflow-hidden">
          <table className="w-full text-right text-sm">
            <thead className="bg-gray-100 text-gray-700">
              <tr>
                <th className="p-3">الدواء</th>
                <th className="p-3">الجرعة</th>
                <th className="p-3">التكرار والمدة</th>
                <th className="p-3">إجراء</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {medications.map((m) => (
                <tr key={m.id}>
                  <td className="p-3 font-medium text-gray-900">{m.name}</td>
                  <td className="p-3 text-gray-600">{m.dose}</td>
                  <td className="p-3 text-gray-600">{m.frequency} - {m.duration}</td>
                  <td className="p-3">
                    <button
                      type="button"
                      onClick={() => handleRemove(m.id)}
                      className="text-red-600 hover:text-red-800 text-xs"
                    >
                      حذف
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="flex justify-end">
        <button
          type="button"
          onClick={handleSave}
          className="px-4 py-2 bg-primary text-white rounded-md text-sm font-medium hover:bg-primary/90 transition"
        >
          حفظ وإصدار الروشتة
        </button>
      </div>
    </div>
  );
}
