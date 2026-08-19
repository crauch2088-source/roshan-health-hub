import { useState } from 'react';
import { vitalSeverity, vitalClass } from '../vitals-utils';

interface VitalsTabProps {
  visitId: string;
}

export function VitalsTab({ visitId }: VitalsTabProps) {
  const [temp, setTemp] = useState('37');
  const [hr, setHr] = useState('80');
  const [spo2, setSpo2] = useState('98');

  const tempNum = parseFloat(temp) || 37;
  const hrNum = parseInt(hr) || 80;
  const spo2Num = parseInt(spo2) || 98;

  const tempSev = vitalSeverity(tempNum, 'temp');
  const hrSev = vitalSeverity(hrNum, 'hr');
  const spo2Sev = vitalSeverity(spo2Num, 'spo2');

  const handleSave = () => {
    alert(`تم حفظ العلامات الحيوية بنجاح للزيارة: ${visitId}`);
  };

  return (
    <div className="space-y-6">
      <h2 className="text-lg font-semibold text-gray-900">قياسات العلامات الحيوية (Vitals)</h2>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* درجة الحرارة */}
        <div className={`p-4 rounded-lg border ${vitalClass(tempSev)}`}>
          <label className="block text-sm font-medium mb-1">درجة الحرارة (°C)</label>
          <input
            type="number"
            step="0.1"
            value={temp}
            onChange={(e) => setTemp(e.target.value)}
            className="w-full bg-white rounded border border-gray-300 p-2 text-sm"
          />
        </div>

        {/* نبض القلب */}
        <div className={`p-4 rounded-lg border ${vitalClass(hrSev)}`}>
          <label className="block text-sm font-medium mb-1">نبض القلب (BPM)</label>
          <input
            type="number"
            value={hr}
            onChange={(e) => setHr(e.target.value)}
            className="w-full bg-white rounded border border-gray-300 p-2 text-sm"
          />
        </div>

        {/* تشبع الأكسجين */}
        <div className={`p-4 rounded-lg border ${vitalClass(spo2Sev)}`}>
          <label className="block text-sm font-medium mb-1">تشبع الأكسجين (SpO2 %)</label>
          <input
            type="number"
            value={spo2}
            onChange={(e) => setSpo2(e.target.value)}
            className="w-full bg-white rounded border border-gray-300 p-2 text-sm"
          />
        </div>
      </div>

      <div className="flex justify-end">
        <button
          type="button"
          onClick={handleSave}
          className="px-4 py-2 bg-primary text-white rounded-md text-sm font-medium hover:bg-primary/90 transition"
        >
          حفظ العلامات الحيوية
        </button>
      </div>
    </div>
  );
}
