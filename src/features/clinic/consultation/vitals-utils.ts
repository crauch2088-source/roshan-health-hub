export function vitalSeverity(value: number, type: 'bp' | 'hr' | 'temp' | 'spo2'): 'normal' | 'warning' | 'danger' {
  if (type === 'temp') {
    if (value > 38.5) return 'danger';
    if (value > 37.5) return 'warning';
    return 'normal';
  }
  if (type === 'hr') {
    if (value > 120 || value < 50) return 'danger';
    if (value > 100 || value < 60) return 'warning';
    return 'normal';
  }
  if (type === 'spo2') {
    if (value < 90) return 'danger';
    if (value < 95) return 'warning';
    return 'normal';
  }
  return 'normal';
}

export function vitalClass(severity: 'normal' | 'warning' | 'danger'): string {
  switch (severity) {
    case 'danger':
      return 'bg-red-100 text-red-800 border-red-300';
    case 'warning':
      return 'bg-yellow-100 text-yellow-800 border-yellow-300';
    default:
      return 'bg-green-100 text-green-800 border-green-300';
  }
}
