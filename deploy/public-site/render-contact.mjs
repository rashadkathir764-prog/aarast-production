// RA-OP-21: writes the owner's contact details and legal entity into the
// support, terms and privacy pages when the image is built, and checks that
// none of them is left. None of the values is in the repository: the pages
// carry {{TOKENS}}, the build takes the values from its arguments, and a page
// that still has a token is not a page to release.
//
//   node render-contact.mjs render <source-dir> <out-dir>   values from the environment
//   node render-contact.mjs check <dir>                     fails while a token is left
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const PAGES = ["support.html", "terms.html", "privacy.html"];
export const VALUE_NAMES = [
  "AARAST_LEGAL_ENTITY",
  "AARAST_SUPPORT_EMAIL",
  "AARAST_SUPPORT_WHATSAPP",
  "AARAST_GOVERNING_LAW",
];
const TOKEN = /\{\{(AARAST_[A-Z_]+)\}\}/g;
const escapeHtml = (text) =>
  text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");

/** Why each given value is not one to publish; empty when all are fine. */
export function validateContact(values) {
  const errors = [];
  const text = (name) => {
    const value = values[name];
    if (value === undefined) return;
    if (!value.trim() || /[<>{}]/.test(value) || value.length > 120 ||
        /^(todo|tbd|placeholder|replace-?me|xxx+)$/i.test(value.trim())) {
      errors.push(`${name} is not a real value`);
    }
  };
  text("AARAST_LEGAL_ENTITY");
  text("AARAST_GOVERNING_LAW");
  const email = values.AARAST_SUPPORT_EMAIL;
  if (email !== undefined) {
    const domain = email.split("@")[1]?.toLowerCase() ?? "";
    if (!/^[^\s@<>"'{}]+@[^\s@<>"'{}]+\.[^\s@<>"'{}]+$/.test(email)) {
      errors.push("AARAST_SUPPORT_EMAIL is not an e-mail address");
    } else if (domain === "aarast.app" || domain.endsWith(".aarast.app")) {
      // RA-ST-01: aarast.app belongs to another company and has no mail.
      errors.push("AARAST_SUPPORT_EMAIL must not be on aarast.app (RA-ST-01)");
    } else if (/(^|\.)example\.(com|org|net)$|\.(example|test|localhost)$/.test(domain)) {
      errors.push("AARAST_SUPPORT_EMAIL is an example address");
    }
  }
  const number = values.AARAST_SUPPORT_WHATSAPP;
  if (number !== undefined &&
      (!/^\+[1-9][0-9]{7,14}$/.test(number) || number === "+967777000111")) {
    errors.push("AARAST_SUPPORT_WHATSAPP must be a real number as +<country code><digits>");
  }
  return errors;
}

/** The tokens of [html] that no value has replaced. */
export function findPlaceholders(html) {
  return [...new Set([...html.matchAll(TOKEN)].map((match) => match[1]))];
}

/** [html] with the tokens [values] has a value for written in, escaped. */
export function renderContact(html, values) {
  const all = { ...values };
  if (values.AARAST_SUPPORT_WHATSAPP) {
    all.AARAST_SUPPORT_WHATSAPP_DIGITS = values.AARAST_SUPPORT_WHATSAPP.replace(/\D/g, "");
  }
  return html.replace(TOKEN, (token, name) => (all[name] ? escapeHtml(all[name]) : token));
}

function valuesFromEnvironment(env) {
  return Object.fromEntries(VALUE_NAMES.filter((name) => env[name]?.trim()).map((name) => [name, env[name].trim()]));
}

function main([command, first, second]) {
  if (command === "render" && first && second) {
    const values = valuesFromEnvironment(process.env);
    const errors = validateContact(values);
    if (errors.length) {
      console.error(`FAIL: ${errors.join("; ")}`);
      return 1;
    }
    mkdirSync(resolve(second), { recursive: true });
    for (const page of PAGES) {
      writeFileSync(join(resolve(second), page), renderContact(readFileSync(join(resolve(first), page), "utf8"), values));
    }
    const missing = VALUE_NAMES.filter((name) => !(name in values));
    console.log(missing.length ? `rendered; still placeholders: ${missing.join(", ")}` : "rendered with every value");
    return 0;
  }
  if (command === "check" && first) {
    const left = [];
    for (const page of readdirSync(resolve(first)).filter((name) => name.endsWith(".html"))) {
      for (const token of findPlaceholders(readFileSync(join(resolve(first), page), "utf8"))) {
        left.push(`${page}: ${token}`);
      }
    }
    if (left.length) {
      console.error(`FAIL: the owner's contact details are still placeholders (set the build arguments):\n  ${left.join("\n  ")}`);
      return 1;
    }
    console.log("PASS: no placeholder is left on the public pages");
    return 0;
  }
  console.error("usage: render-contact.mjs render <source-dir> <out-dir> | check <dir>");
  return 2;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
