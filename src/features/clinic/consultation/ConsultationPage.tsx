import { useState } from 'react';
import { ClinicalNoteTab } from './components/ClinicalNoteTab';
import { VitalsTab } from './components/VitalsTab';
import { LaboratoryTab } from './components/LaboratoryTab';
import { PrescriptionTab } from './components/PrescriptionTab';
import { HistoryTab } from './components/HistoryTab';

interface ConsultationPageProps {
  visitId: string;
}

export function ConsultationPage({ visitId }: ConsultationPageProps) {
  const [activeTab, setActiveTab] = useState<'note' | 'vitals' | 'labs' | 'prescription' | 'history'>('note');

  return (
    <div className="container mx-auto p-4 max-w-7xl">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold tracking-tight">صفحة الكشف الطبي (زيارة: {visitId})</h1>
      </div>

      {/* شريط التبويبات (Tabs Navigation) */}
      <div className="flex border-b border-gray-200 mb-6 overflow-x-auto">
        <button
          onClick={() => setActiveTab('note')}
          className={`py-2 px-4 font-medium text-sm border-b-2 whitespace-nowrap ${
            activeTab === 'note' ? 'border-primary text-primary' : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
        >
          الملاحظات الإكلينيكية
        </button>
        <button
          onClick={() => setActiveTab('vitals')}
          className={`py-2 px-4 font-medium text-sm border-b-2 whitespace-nowrap ${
            activeTab === 'vitals' ? 'border-primary text-primary' : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
        >
          العلامات الحيوية
        </button>
        <button
          onClick={() => setActiveTab('labs')}
          className={`py-2 px-4 font-medium text-sm border-b-2 whitespace-nowrap ${
            activeTab === 'labs' ? 'border-primary text-primary' : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
        >
          التحاليل والفحوصات
        </button>
        <button
          onClick={() => setActiveTab('prescription')}
          className={`py-2 px-4 font-medium text-sm border-b-2 whitespace-nowrap ${
            activeTab === 'prescription' ? 'border-primary text-primary' : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
        >
          الروشتة والأدوية
        </button>
        <button
          onClick={() => setActiveTab('history')}
          className={`py-2 px-4 font-medium text-sm border-b-2 whitespace-nowrap ${
            activeTab === 'history' ? 'border-primary text-primary' : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
        >
          السجل الطبي
        </button>
      </div>

      {/* محتوى التبويبات */}
      <div className="bg-white rounded-lg shadow p-6">
        {activeTab === 'note' && <ClinicalNoteTab visitId={visitId} />}
        {activeTab === 'vitals' && <VitalsTab visitId={visitId} />}
        {activeTab === 'labs' && <LaboratoryTab visitId={visitId} />}
        {activeTab === 'prescription' && <PrescriptionTab visitId={visitId} />}
        {activeTab === 'history' && <HistoryTab visitId={visitId} />}
      </div>
    </div>
  );
}
