/**
 * Decide whether a dirty clinical note should block an in-app navigation.
 * A declined confirmation blocks the transition; clean and same-location
 * transitions never prompt.
 */
export function shouldBlockUnsavedClinicalNoteNavigation(
  isDirty: boolean,
  currentLocation: string,
  nextLocation: string,
  confirmLeave: () => boolean,
): boolean {
  if (!isDirty || currentLocation === nextLocation) return false;
  return !confirmLeave();
}
