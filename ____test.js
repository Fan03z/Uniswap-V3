// 根据两个token的相对价格p(y / x),计算出tick
function price_to_tick(p) {
  return Math.floor(Math.log(p) / Math.log(1.0001));
}

price_to_tick(5000);

// 由64位整数位和96位小数位表示的定点数格式表示: p^(1/2)
let q96 = 2n ** 96n;
function price_to_sqrtp(p) {
  let binInt = BigInt(Math.sqrt(p).toString().replace(".", "")) * q96;
  return binInt;
}

price_to_sqrtp(5000);
