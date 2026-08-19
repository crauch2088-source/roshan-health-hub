interface HistoryTabProps {
  visitId: string;
}

export function HistoryTab({ visitId }: HistoryTabProps) {
  // بيانات تجريبية للسجل الطبي السابق للزيارة
  const pastVisits = [
    { id: 'v-101', date: '2026-06-15', diagnosis: 'التهاب حاد في الحلق', doctor: 'د. محمد' },
    { id: 'v-100', date: '2026-05-01', diagnosis: 'متابعة ضغط الدم', doctor: 'د. محمد' },
  ];

  return (
    <div className="space-y-6">
      <h2 className="text-lg font-semibold text-gray-900">السجل الطبي والزيارات السابقة</h2>
      <p className="text-sm text-gray-600">عرض السجل الطبي المرتبط بهذه الزيارة (معرف الزيارة الحالي: {visitId})</p>

      <div className="space-y-3">
        {pastVisits.map((visit) => (
          <div key={visit.id} className="p-4 rounded-lg border border-gray-200 bg-gray-50 flex flex-col md:flex-row md:items-center md:justify-between gap-2">
            <div>
              <span className="text-xs font-semibold text-primary bg-primary/10 px-2 py-0.5 rounded">
                {visit.date}
              </span>
              <h3 className="text-sm font-medium text-gray-900 mt-1">التشخيص: {visit.diagnosis}</h3>
            </div>
            <div className="text-xs text-gray-500">
              الطبيب المعالج: {visit.doctor}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
