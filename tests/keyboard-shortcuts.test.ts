import assert from "node:assert/strict";
import { test } from "node:test";

import { resolveKeyboardShortcut } from "../src/lib/keyboard-shortcuts.ts";

const baseInput = {
  code: "KeyK",
  ctrlKey: true,
  metaKey: false,
  shiftKey: false,
  altKey: false,
  isComposing: false,
  repeat: false,
  typing: false,
};

const permissionForRoute = (path: string) =>
  ({
    "/dashboard": "dashboard.read",
    "/patients": "patients.read",
    "/visits": "visits.read",
    "/appointments": "appointments.read",
    "/billing": "billing.read",
    "/lab": "lab.read",
    "/pharmacy": "pharmacy.read",
  })[path];

test("Ctrl/Cmd+K uses the physical key code and works across keyboard layouts", () => {
  assert.deepEqual(
    resolveKeyboardShortcut({ ...baseInput, code: "KeyK" }, () => true, permissionForRoute),
    { type: "search" },
  );
});

test("navigation shortcuts use physical key codes and enforce route permissions", () => {
  assert.deepEqual(
    resolveKeyboardShortcut(
      { ...baseInput, code: "KeyP", shiftKey: true },
      (permission) => permission === "patients.read",
      permissionForRoute,
    ),
    { type: "navigate", path: "/patients" },
  );
  assert.deepEqual(
    resolveKeyboardShortcut(
      { ...baseInput, code: "KeyP", shiftKey: true },
      () => false,
      permissionForRoute,
    ),
    { type: "none" },
  );
});

test("navigation shortcuts do not fire while typing or during IME composition", () => {
  assert.deepEqual(
    resolveKeyboardShortcut(
      { ...baseInput, code: "KeyP", shiftKey: true, typing: true },
      () => true,
      permissionForRoute,
    ),
    { type: "none" },
  );
  assert.deepEqual(
    resolveKeyboardShortcut(
      { ...baseInput, code: "KeyP", shiftKey: true, isComposing: true },
      () => true,
      permissionForRoute,
    ),
    { type: "none" },
  );
});

test("unknown and unmodified keys do nothing", () => {
  assert.deepEqual(
    resolveKeyboardShortcut(
      { ...baseInput, code: "KeyZ", shiftKey: true },
      () => true,
      permissionForRoute,
    ),
    { type: "none" },
  );
  assert.deepEqual(
    resolveKeyboardShortcut(
      { ...baseInput, code: "KeyP", ctrlKey: false },
      () => true,
      permissionForRoute,
    ),
    { type: "none" },
  );
});
