import { load, eq, ok } from "./lib.mjs";
const c = load("calc.js");
eq(c.evaluate("2+2"), 4, "add");
eq(c.evaluate("2^10"), 1024, "power");
eq(c.evaluate("-2^2"), -4, "unary minus binds looser than ^");
eq(c.evaluate("(1+2)*3"), 9, "parens");
eq(c.evaluate("sqrt(16) + abs(-3)"), 7, "functions");
ok(Math.abs(c.evaluate("sin(pi/2)") - 1) < 1e-12, "sin pi");
eq(c.evaluate("10 % 4"), 2, "modulo");
eq(c.evaluate("1,5 * 2"), 3, "comma decimal");
eq(c.evaluate("2 3"), null, "garbage → null");
eq(c.evaluate("alert(1)"), null, "unknown function rejected");
eq(c.evaluate("constructor"), null, "identifier rejected");
eq(c.evaluate("1/0"), null, "infinity rejected");
eq(c.evaluate(""), null, "empty");
eq(c.looksLikeMath("hello"), false, "plain word is not math");
eq(c.looksLikeMath("12*3"), true, "expression is math");
eq(c.convert("5 km to mi").toFixed(3), "3.107", "length");
eq(c.convert("100 c to f"), 212, "temperature");
eq(c.convert("1 gib to mb").toFixed(1), "1073.7", "data");
eq(c.convert("3 parsecs to km"), null, "unknown unit");

// Currencies: rates are per USD (open.er-api.com, cached a day by the launcher).
{
  const rates = { USD: 1, RUB: 90, EUR: 0.9 };
  eq(c.convertCurrency("10 usd to rub", rates), 900, "usd → rub");
  eq(c.convertCurrency("90 rub in usd", rates), 1, "rub → usd");
  eq(c.convertCurrency("9 eur to rub", rates), 900, "through usd");
  eq(c.convertCurrency("10 $ to ₽", rates), 900, "symbols");
  eq(c.convertCurrency("10 usd to xyz", rates), null, "unknown currency");
  eq(c.convertCurrency("10 usd to rub", null), null, "no rates yet");
  eq(c.convertCurrency("10 km to mi", rates), null, "not money");
  eq(c.isCurrencyQuery("5 eur in rub"), true, "looks like money");
  eq(c.isCurrencyQuery("5 km in mi"), false, "units are not money");
}
