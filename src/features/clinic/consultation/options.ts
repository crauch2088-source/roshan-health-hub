export interface QuickOption {
  id: string;
  label: string;
  category?: string;
}

export const QUICK_COMPLAINTS: QuickOption[] = [
  { id: '1', label: 'صداع مزمن' },
  { id: '2', label: 'ارتفاع ضغط الدم' },
  { id: '3', label: 'آلام البطن' },
  { id: '4', label: 'التهاب الحلق والزكام' },
];

export const DOSES = [
  'قرص واحد',
  'قرصان',
  '5 مل',
  '10 مل',
  'نصف قرص',
];

export const FREQUENCIES = [
  'مرة يومياً',
  'مرتان يومياً',
  '3 مرات يومياً',
  'عند اللزوم',
];

export const DURATIONS = [
  '3 أيام',
  '5 أيام',
  'أسبوع',
  'أسبوعان',
  'شهر',
];
