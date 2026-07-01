(function(){const e=document.createElement("link").relList;if(e&&e.supports&&e.supports("modulepreload"))return;for(const n of document.querySelectorAll('link[rel="modulepreload"]'))r(n);new MutationObserver(n=>{for(const o of n)if(o.type==="childList")for(const s of o.addedNodes)s.tagName==="LINK"&&s.rel==="modulepreload"&&r(s)}).observe(document,{childList:!0,subtree:!0});function i(n){const o={};return n.integrity&&(o.integrity=n.integrity),n.referrerPolicy&&(o.referrerPolicy=n.referrerPolicy),n.crossOrigin==="use-credentials"?o.credentials="include":n.crossOrigin==="anonymous"?o.credentials="omit":o.credentials="same-origin",o}function r(n){if(n.ep)return;n.ep=!0;const o=i(n);fetch(n.href,o)}})();function Ee(t){return t&&t.__esModule&&Object.prototype.hasOwnProperty.call(t,"default")?t.default:t}var O={},lt,Ft;function Be(){return Ft||(Ft=1,lt=function(){return typeof Promise=="function"&&Promise.prototype&&Promise.prototype.then}),lt}var ct={},z={},$t;function H(){if($t)return z;$t=1;let t;const e=[0,26,44,70,100,134,172,196,242,292,346,404,466,532,581,655,733,815,901,991,1085,1156,1258,1364,1474,1588,1706,1828,1921,2051,2185,2323,2465,2611,2761,2876,3034,3196,3362,3532,3706];return z.getSymbolSize=function(r){if(!r)throw new Error('"version" cannot be null or undefined');if(r<1||r>40)throw new Error('"version" should be in range from 1 to 40');return r*4+17},z.getSymbolTotalCodewords=function(r){return e[r]},z.getBCHDigit=function(i){let r=0;for(;i!==0;)r++,i>>>=1;return r},z.setToSJISFunction=function(r){if(typeof r!="function")throw new Error('"toSJISFunc" is not a valid function.');t=r},z.isKanjiModeEnabled=function(){return typeof t<"u"},z.toSJIS=function(r){return t(r)},z}var ut={},zt;function Lt(){return zt||(zt=1,(function(t){t.L={bit:1},t.M={bit:0},t.Q={bit:3},t.H={bit:2};function e(i){if(typeof i!="string")throw new Error("Param is not a string");switch(i.toLowerCase()){case"l":case"low":return t.L;case"m":case"medium":return t.M;case"q":case"quartile":return t.Q;case"h":case"high":return t.H;default:throw new Error("Unknown EC Level: "+i)}}t.isValid=function(r){return r&&typeof r.bit<"u"&&r.bit>=0&&r.bit<4},t.from=function(r,n){if(t.isValid(r))return r;try{return e(r)}catch{return n}}})(ut)),ut}var dt,Ht;function Se(){if(Ht)return dt;Ht=1;function t(){this.buffer=[],this.length=0}return t.prototype={get:function(e){const i=Math.floor(e/8);return(this.buffer[i]>>>7-e%8&1)===1},put:function(e,i){for(let r=0;r<i;r++)this.putBit((e>>>i-r-1&1)===1)},getLengthInBits:function(){return this.length},putBit:function(e){const i=Math.floor(this.length/8);this.buffer.length<=i&&this.buffer.push(0),e&&(this.buffer[i]|=128>>>this.length%8),this.length++}},dt=t,dt}var ft,Vt;function Ae(){if(Vt)return ft;Vt=1;function t(e){if(!e||e<1)throw new Error("BitMatrix size must be defined and greater than 0");this.size=e,this.data=new Uint8Array(e*e),this.reservedBit=new Uint8Array(e*e)}return t.prototype.set=function(e,i,r,n){const o=e*this.size+i;this.data[o]=r,n&&(this.reservedBit[o]=!0)},t.prototype.get=function(e,i){return this.data[e*this.size+i]},t.prototype.xor=function(e,i,r){this.data[e*this.size+i]^=r},t.prototype.isReserved=function(e,i){return this.reservedBit[e*this.size+i]},ft=t,ft}var ht={},Kt;function Te(){return Kt||(Kt=1,(function(t){const e=H().getSymbolSize;t.getRowColCoords=function(r){if(r===1)return[];const n=Math.floor(r/7)+2,o=e(r),s=o===145?26:Math.ceil((o-13)/(2*n-2))*2,a=[o-7];for(let l=1;l<n-1;l++)a[l]=a[l-1]-s;return a.push(6),a.reverse()},t.getPositions=function(r){const n=[],o=t.getRowColCoords(r),s=o.length;for(let a=0;a<s;a++)for(let l=0;l<s;l++)a===0&&l===0||a===0&&l===s-1||a===s-1&&l===0||n.push([o[a],o[l]]);return n}})(ht)),ht}var gt={},Ot;function Me(){if(Ot)return gt;Ot=1;const t=H().getSymbolSize,e=7;return gt.getPositions=function(r){const n=t(r);return[[0,0],[n-e,0],[0,n-e]]},gt}var pt={},jt;function Ie(){return jt||(jt=1,(function(t){t.Patterns={PATTERN000:0,PATTERN001:1,PATTERN010:2,PATTERN011:3,PATTERN100:4,PATTERN101:5,PATTERN110:6,PATTERN111:7};const e={N1:3,N2:3,N3:40,N4:10};t.isValid=function(n){return n!=null&&n!==""&&!isNaN(n)&&n>=0&&n<=7},t.from=function(n){return t.isValid(n)?parseInt(n,10):void 0},t.getPenaltyN1=function(n){const o=n.size;let s=0,a=0,l=0,c=null,f=null;for(let v=0;v<o;v++){a=l=0,c=f=null;for(let g=0;g<o;g++){let u=n.get(v,g);u===c?a++:(a>=5&&(s+=e.N1+(a-5)),c=u,a=1),u=n.get(g,v),u===f?l++:(l>=5&&(s+=e.N1+(l-5)),f=u,l=1)}a>=5&&(s+=e.N1+(a-5)),l>=5&&(s+=e.N1+(l-5))}return s},t.getPenaltyN2=function(n){const o=n.size;let s=0;for(let a=0;a<o-1;a++)for(let l=0;l<o-1;l++){const c=n.get(a,l)+n.get(a,l+1)+n.get(a+1,l)+n.get(a+1,l+1);(c===4||c===0)&&s++}return s*e.N2},t.getPenaltyN3=function(n){const o=n.size;let s=0,a=0,l=0;for(let c=0;c<o;c++){a=l=0;for(let f=0;f<o;f++)a=a<<1&2047|n.get(c,f),f>=10&&(a===1488||a===93)&&s++,l=l<<1&2047|n.get(f,c),f>=10&&(l===1488||l===93)&&s++}return s*e.N3},t.getPenaltyN4=function(n){let o=0;const s=n.data.length;for(let l=0;l<s;l++)o+=n.data[l];return Math.abs(Math.ceil(o*100/s/5)-10)*e.N4};function i(r,n,o){switch(r){case t.Patterns.PATTERN000:return(n+o)%2===0;case t.Patterns.PATTERN001:return n%2===0;case t.Patterns.PATTERN010:return o%3===0;case t.Patterns.PATTERN011:return(n+o)%3===0;case t.Patterns.PATTERN100:return(Math.floor(n/2)+Math.floor(o/3))%2===0;case t.Patterns.PATTERN101:return n*o%2+n*o%3===0;case t.Patterns.PATTERN110:return(n*o%2+n*o%3)%2===0;case t.Patterns.PATTERN111:return(n*o%3+(n+o)%2)%2===0;default:throw new Error("bad maskPattern:"+r)}}t.applyMask=function(n,o){const s=o.size;for(let a=0;a<s;a++)for(let l=0;l<s;l++)o.isReserved(l,a)||o.xor(l,a,i(n,l,a))},t.getBestMask=function(n,o){const s=Object.keys(t.Patterns).length;let a=0,l=1/0;for(let c=0;c<s;c++){o(c),t.applyMask(c,n);const f=t.getPenaltyN1(n)+t.getPenaltyN2(n)+t.getPenaltyN3(n)+t.getPenaltyN4(n);t.applyMask(c,n),f<l&&(l=f,a=c)}return a}})(pt)),pt}var tt={},Jt;function ge(){if(Jt)return tt;Jt=1;const t=Lt(),e=[1,1,1,1,1,1,1,1,1,1,2,2,1,2,2,4,1,2,4,4,2,4,4,4,2,4,6,5,2,4,6,6,2,5,8,8,4,5,8,8,4,5,8,11,4,8,10,11,4,9,12,16,4,9,16,16,6,10,12,18,6,10,17,16,6,11,16,19,6,13,18,21,7,14,21,25,8,16,20,25,8,17,23,25,9,17,23,34,9,18,25,30,10,20,27,32,12,21,29,35,12,23,34,37,12,25,34,40,13,26,35,42,14,28,38,45,15,29,40,48,16,31,43,51,17,33,45,54,18,35,48,57,19,37,51,60,19,38,53,63,20,40,56,66,21,43,59,70,22,45,62,74,24,47,65,77,25,49,68,81],i=[7,10,13,17,10,16,22,28,15,26,36,44,20,36,52,64,26,48,72,88,36,64,96,112,40,72,108,130,48,88,132,156,60,110,160,192,72,130,192,224,80,150,224,264,96,176,260,308,104,198,288,352,120,216,320,384,132,240,360,432,144,280,408,480,168,308,448,532,180,338,504,588,196,364,546,650,224,416,600,700,224,442,644,750,252,476,690,816,270,504,750,900,300,560,810,960,312,588,870,1050,336,644,952,1110,360,700,1020,1200,390,728,1050,1260,420,784,1140,1350,450,812,1200,1440,480,868,1290,1530,510,924,1350,1620,540,980,1440,1710,570,1036,1530,1800,570,1064,1590,1890,600,1120,1680,1980,630,1204,1770,2100,660,1260,1860,2220,720,1316,1950,2310,750,1372,2040,2430];return tt.getBlocksCount=function(n,o){switch(o){case t.L:return e[(n-1)*4+0];case t.M:return e[(n-1)*4+1];case t.Q:return e[(n-1)*4+2];case t.H:return e[(n-1)*4+3];default:return}},tt.getTotalCodewordsCount=function(n,o){switch(o){case t.L:return i[(n-1)*4+0];case t.M:return i[(n-1)*4+1];case t.Q:return i[(n-1)*4+2];case t.H:return i[(n-1)*4+3];default:return}},tt}var mt={},Q={},xt;function Re(){if(xt)return Q;xt=1;const t=new Uint8Array(512),e=new Uint8Array(256);return(function(){let r=1;for(let n=0;n<255;n++)t[n]=r,e[r]=n,r<<=1,r&256&&(r^=285);for(let n=255;n<512;n++)t[n]=t[n-255]})(),Q.log=function(r){if(r<1)throw new Error("log("+r+")");return e[r]},Q.exp=function(r){return t[r]},Q.mul=function(r,n){return r===0||n===0?0:t[e[r]+e[n]]},Q}var Yt;function _e(){return Yt||(Yt=1,(function(t){const e=Re();t.mul=function(r,n){const o=new Uint8Array(r.length+n.length-1);for(let s=0;s<r.length;s++)for(let a=0;a<n.length;a++)o[s+a]^=e.mul(r[s],n[a]);return o},t.mod=function(r,n){let o=new Uint8Array(r);for(;o.length-n.length>=0;){const s=o[0];for(let l=0;l<n.length;l++)o[l]^=e.mul(n[l],s);let a=0;for(;a<o.length&&o[a]===0;)a++;o=o.slice(a)}return o},t.generateECPolynomial=function(r){let n=new Uint8Array([1]);for(let o=0;o<r;o++)n=t.mul(n,new Uint8Array([1,e.exp(o)]));return n}})(mt)),mt}var yt,Gt;function Pe(){if(Gt)return yt;Gt=1;const t=_e();function e(i){this.genPoly=void 0,this.degree=i,this.degree&&this.initialize(this.degree)}return e.prototype.initialize=function(r){this.degree=r,this.genPoly=t.generateECPolynomial(this.degree)},e.prototype.encode=function(r){if(!this.genPoly)throw new Error("Encoder not initialized");const n=new Uint8Array(r.length+this.degree);n.set(r);const o=t.mod(n,this.genPoly),s=this.degree-o.length;if(s>0){const a=new Uint8Array(this.degree);return a.set(o,s),a}return o},yt=e,yt}var wt={},bt={},vt={},Qt;function pe(){return Qt||(Qt=1,vt.isValid=function(e){return!isNaN(e)&&e>=1&&e<=40}),vt}var k={},Zt;function me(){if(Zt)return k;Zt=1;const t="[0-9]+",e="[A-Z $%*+\\-./:]+";let i="(?:[u3000-u303F]|[u3040-u309F]|[u30A0-u30FF]|[uFF00-uFFEF]|[u4E00-u9FAF]|[u2605-u2606]|[u2190-u2195]|u203B|[u2010u2015u2018u2019u2025u2026u201Cu201Du2225u2260]|[u0391-u0451]|[u00A7u00A8u00B1u00B4u00D7u00F7])+";i=i.replace(/u/g,"\\u");const r="(?:(?![A-Z0-9 $%*+\\-./:]|"+i+`)(?:.|[\r
]))+`;k.KANJI=new RegExp(i,"g"),k.BYTE_KANJI=new RegExp("[^A-Z0-9 $%*+\\-./:]+","g"),k.BYTE=new RegExp(r,"g"),k.NUMERIC=new RegExp(t,"g"),k.ALPHANUMERIC=new RegExp(e,"g");const n=new RegExp("^"+i+"$"),o=new RegExp("^"+t+"$"),s=new RegExp("^[A-Z0-9 $%*+\\-./:]+$");return k.testKanji=function(l){return n.test(l)},k.testNumeric=function(l){return o.test(l)},k.testAlphanumeric=function(l){return s.test(l)},k}var Wt;function V(){return Wt||(Wt=1,(function(t){const e=pe(),i=me();t.NUMERIC={id:"Numeric",bit:1,ccBits:[10,12,14]},t.ALPHANUMERIC={id:"Alphanumeric",bit:2,ccBits:[9,11,13]},t.BYTE={id:"Byte",bit:4,ccBits:[8,16,16]},t.KANJI={id:"Kanji",bit:8,ccBits:[8,10,12]},t.MIXED={bit:-1},t.getCharCountIndicator=function(o,s){if(!o.ccBits)throw new Error("Invalid mode: "+o);if(!e.isValid(s))throw new Error("Invalid version: "+s);return s>=1&&s<10?o.ccBits[0]:s<27?o.ccBits[1]:o.ccBits[2]},t.getBestModeForData=function(o){return i.testNumeric(o)?t.NUMERIC:i.testAlphanumeric(o)?t.ALPHANUMERIC:i.testKanji(o)?t.KANJI:t.BYTE},t.toString=function(o){if(o&&o.id)return o.id;throw new Error("Invalid mode")},t.isValid=function(o){return o&&o.bit&&o.ccBits};function r(n){if(typeof n!="string")throw new Error("Param is not a string");switch(n.toLowerCase()){case"numeric":return t.NUMERIC;case"alphanumeric":return t.ALPHANUMERIC;case"kanji":return t.KANJI;case"byte":return t.BYTE;default:throw new Error("Unknown mode: "+n)}}t.from=function(o,s){if(t.isValid(o))return o;try{return r(o)}catch{return s}}})(bt)),bt}var Xt;function Ne(){return Xt||(Xt=1,(function(t){const e=H(),i=ge(),r=Lt(),n=V(),o=pe(),s=7973,a=e.getBCHDigit(s);function l(g,u,T){for(let M=1;M<=40;M++)if(u<=t.getCapacity(M,T,g))return M}function c(g,u){return n.getCharCountIndicator(g,u)+4}function f(g,u){let T=0;return g.forEach(function(M){const _=c(M.mode,u);T+=_+M.getBitsLength()}),T}function v(g,u){for(let T=1;T<=40;T++)if(f(g,T)<=t.getCapacity(T,u,n.MIXED))return T}t.from=function(u,T){return o.isValid(u)?parseInt(u,10):T},t.getCapacity=function(u,T,M){if(!o.isValid(u))throw new Error("Invalid QR Code version");typeof M>"u"&&(M=n.BYTE);const _=e.getSymbolTotalCodewords(u),B=i.getTotalCodewordsCount(u,T),I=(_-B)*8;if(M===n.MIXED)return I;const S=I-c(M,u);switch(M){case n.NUMERIC:return Math.floor(S/10*3);case n.ALPHANUMERIC:return Math.floor(S/11*2);case n.KANJI:return Math.floor(S/13);case n.BYTE:default:return Math.floor(S/8)}},t.getBestVersionForData=function(u,T){let M;const _=r.from(T,r.M);if(Array.isArray(u)){if(u.length>1)return v(u,_);if(u.length===0)return 1;M=u[0]}else M=u;return l(M.mode,M.getLength(),_)},t.getEncodedBits=function(u){if(!o.isValid(u)||u<7)throw new Error("Invalid QR Code version");let T=u<<12;for(;e.getBCHDigit(T)-a>=0;)T^=s<<e.getBCHDigit(T)-a;return u<<12|T}})(wt)),wt}var Ct={},te;function Le(){if(te)return Ct;te=1;const t=H(),e=1335,i=21522,r=t.getBCHDigit(e);return Ct.getEncodedBits=function(o,s){const a=o.bit<<3|s;let l=a<<10;for(;t.getBCHDigit(l)-r>=0;)l^=e<<t.getBCHDigit(l)-r;return(a<<10|l)^i},Ct}var Et={},Bt,ee;function qe(){if(ee)return Bt;ee=1;const t=V();function e(i){this.mode=t.NUMERIC,this.data=i.toString()}return e.getBitsLength=function(r){return 10*Math.floor(r/3)+(r%3?r%3*3+1:0)},e.prototype.getLength=function(){return this.data.length},e.prototype.getBitsLength=function(){return e.getBitsLength(this.data.length)},e.prototype.write=function(r){let n,o,s;for(n=0;n+3<=this.data.length;n+=3)o=this.data.substr(n,3),s=parseInt(o,10),r.put(s,10);const a=this.data.length-n;a>0&&(o=this.data.substr(n),s=parseInt(o,10),r.put(s,a*3+1))},Bt=e,Bt}var St,ne;function ke(){if(ne)return St;ne=1;const t=V(),e=["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"," ","$","%","*","+","-",".","/",":"];function i(r){this.mode=t.ALPHANUMERIC,this.data=r}return i.getBitsLength=function(n){return 11*Math.floor(n/2)+6*(n%2)},i.prototype.getLength=function(){return this.data.length},i.prototype.getBitsLength=function(){return i.getBitsLength(this.data.length)},i.prototype.write=function(n){let o;for(o=0;o+2<=this.data.length;o+=2){let s=e.indexOf(this.data[o])*45;s+=e.indexOf(this.data[o+1]),n.put(s,11)}this.data.length%2&&n.put(e.indexOf(this.data[o]),6)},St=i,St}var At,re;function De(){if(re)return At;re=1;const t=V();function e(i){this.mode=t.BYTE,typeof i=="string"?this.data=new TextEncoder().encode(i):this.data=new Uint8Array(i)}return e.getBitsLength=function(r){return r*8},e.prototype.getLength=function(){return this.data.length},e.prototype.getBitsLength=function(){return e.getBitsLength(this.data.length)},e.prototype.write=function(i){for(let r=0,n=this.data.length;r<n;r++)i.put(this.data[r],8)},At=e,At}var Tt,oe;function Ue(){if(oe)return Tt;oe=1;const t=V(),e=H();function i(r){this.mode=t.KANJI,this.data=r}return i.getBitsLength=function(n){return n*13},i.prototype.getLength=function(){return this.data.length},i.prototype.getBitsLength=function(){return i.getBitsLength(this.data.length)},i.prototype.write=function(r){let n;for(n=0;n<this.data.length;n++){let o=e.toSJIS(this.data[n]);if(o>=33088&&o<=40956)o-=33088;else if(o>=57408&&o<=60351)o-=49472;else throw new Error("Invalid SJIS character: "+this.data[n]+`
Make sure your charset is UTF-8`);o=(o>>>8&255)*192+(o&255),r.put(o,13)}},Tt=i,Tt}var Mt={exports:{}},ie;function Fe(){return ie||(ie=1,(function(t){var e={single_source_shortest_paths:function(i,r,n){var o={},s={};s[r]=0;var a=e.PriorityQueue.make();a.push(r,0);for(var l,c,f,v,g,u,T,M,_;!a.empty();){l=a.pop(),c=l.value,v=l.cost,g=i[c]||{};for(f in g)g.hasOwnProperty(f)&&(u=g[f],T=v+u,M=s[f],_=typeof s[f]>"u",(_||M>T)&&(s[f]=T,a.push(f,T),o[f]=c))}if(typeof n<"u"&&typeof s[n]>"u"){var B=["Could not find a path from ",r," to ",n,"."].join("");throw new Error(B)}return o},extract_shortest_path_from_predecessor_list:function(i,r){for(var n=[],o=r;o;)n.push(o),i[o],o=i[o];return n.reverse(),n},find_path:function(i,r,n){var o=e.single_source_shortest_paths(i,r,n);return e.extract_shortest_path_from_predecessor_list(o,n)},PriorityQueue:{make:function(i){var r=e.PriorityQueue,n={},o;i=i||{};for(o in r)r.hasOwnProperty(o)&&(n[o]=r[o]);return n.queue=[],n.sorter=i.sorter||r.default_sorter,n},default_sorter:function(i,r){return i.cost-r.cost},push:function(i,r){var n={value:i,cost:r};this.queue.push(n),this.queue.sort(this.sorter)},pop:function(){return this.queue.shift()},empty:function(){return this.queue.length===0}}};t.exports=e})(Mt)),Mt.exports}var se;function $e(){return se||(se=1,(function(t){const e=V(),i=qe(),r=ke(),n=De(),o=Ue(),s=me(),a=H(),l=Fe();function c(B){return unescape(encodeURIComponent(B)).length}function f(B,I,S){const C=[];let P;for(;(P=B.exec(S))!==null;)C.push({data:P[0],index:P.index,mode:I,length:P[0].length});return C}function v(B){const I=f(s.NUMERIC,e.NUMERIC,B),S=f(s.ALPHANUMERIC,e.ALPHANUMERIC,B);let C,P;return a.isKanjiModeEnabled()?(C=f(s.BYTE,e.BYTE,B),P=f(s.KANJI,e.KANJI,B)):(C=f(s.BYTE_KANJI,e.BYTE,B),P=[]),I.concat(S,C,P).sort(function(w,y){return w.index-y.index}).map(function(w){return{data:w.data,mode:w.mode,length:w.length}})}function g(B,I){switch(I){case e.NUMERIC:return i.getBitsLength(B);case e.ALPHANUMERIC:return r.getBitsLength(B);case e.KANJI:return o.getBitsLength(B);case e.BYTE:return n.getBitsLength(B)}}function u(B){return B.reduce(function(I,S){const C=I.length-1>=0?I[I.length-1]:null;return C&&C.mode===S.mode?(I[I.length-1].data+=S.data,I):(I.push(S),I)},[])}function T(B){const I=[];for(let S=0;S<B.length;S++){const C=B[S];switch(C.mode){case e.NUMERIC:I.push([C,{data:C.data,mode:e.ALPHANUMERIC,length:C.length},{data:C.data,mode:e.BYTE,length:C.length}]);break;case e.ALPHANUMERIC:I.push([C,{data:C.data,mode:e.BYTE,length:C.length}]);break;case e.KANJI:I.push([C,{data:C.data,mode:e.BYTE,length:c(C.data)}]);break;case e.BYTE:I.push([{data:C.data,mode:e.BYTE,length:c(C.data)}])}}return I}function M(B,I){const S={},C={start:{}};let P=["start"];for(let h=0;h<B.length;h++){const w=B[h],y=[];for(let d=0;d<w.length;d++){const E=w[d],p=""+h+d;y.push(p),S[p]={node:E,lastCount:0},C[p]={};for(let b=0;b<P.length;b++){const m=P[b];S[m]&&S[m].node.mode===E.mode?(C[m][p]=g(S[m].lastCount+E.length,E.mode)-g(S[m].lastCount,E.mode),S[m].lastCount+=E.length):(S[m]&&(S[m].lastCount=E.length),C[m][p]=g(E.length,E.mode)+4+e.getCharCountIndicator(E.mode,I))}}P=y}for(let h=0;h<P.length;h++)C[P[h]].end=0;return{map:C,table:S}}function _(B,I){let S;const C=e.getBestModeForData(B);if(S=e.from(I,C),S!==e.BYTE&&S.bit<C.bit)throw new Error('"'+B+'" cannot be encoded with mode '+e.toString(S)+`.
 Suggested mode is: `+e.toString(C));switch(S===e.KANJI&&!a.isKanjiModeEnabled()&&(S=e.BYTE),S){case e.NUMERIC:return new i(B);case e.ALPHANUMERIC:return new r(B);case e.KANJI:return new o(B);case e.BYTE:return new n(B)}}t.fromArray=function(I){return I.reduce(function(S,C){return typeof C=="string"?S.push(_(C,null)):C.data&&S.push(_(C.data,C.mode)),S},[])},t.fromString=function(I,S){const C=v(I,a.isKanjiModeEnabled()),P=T(C),h=M(P,S),w=l.find_path(h.map,"start","end"),y=[];for(let d=1;d<w.length-1;d++)y.push(h.table[w[d]].node);return t.fromArray(u(y))},t.rawSplit=function(I){return t.fromArray(v(I,a.isKanjiModeEnabled()))}})(Et)),Et}var ae;function ze(){if(ae)return ct;ae=1;const t=H(),e=Lt(),i=Se(),r=Ae(),n=Te(),o=Me(),s=Ie(),a=ge(),l=Pe(),c=Ne(),f=Le(),v=V(),g=$e();function u(h,w){const y=h.size,d=o.getPositions(w);for(let E=0;E<d.length;E++){const p=d[E][0],b=d[E][1];for(let m=-1;m<=7;m++)if(!(p+m<=-1||y<=p+m))for(let A=-1;A<=7;A++)b+A<=-1||y<=b+A||(m>=0&&m<=6&&(A===0||A===6)||A>=0&&A<=6&&(m===0||m===6)||m>=2&&m<=4&&A>=2&&A<=4?h.set(p+m,b+A,!0,!0):h.set(p+m,b+A,!1,!0))}}function T(h){const w=h.size;for(let y=8;y<w-8;y++){const d=y%2===0;h.set(y,6,d,!0),h.set(6,y,d,!0)}}function M(h,w){const y=n.getPositions(w);for(let d=0;d<y.length;d++){const E=y[d][0],p=y[d][1];for(let b=-2;b<=2;b++)for(let m=-2;m<=2;m++)b===-2||b===2||m===-2||m===2||b===0&&m===0?h.set(E+b,p+m,!0,!0):h.set(E+b,p+m,!1,!0)}}function _(h,w){const y=h.size,d=c.getEncodedBits(w);let E,p,b;for(let m=0;m<18;m++)E=Math.floor(m/3),p=m%3+y-8-3,b=(d>>m&1)===1,h.set(E,p,b,!0),h.set(p,E,b,!0)}function B(h,w,y){const d=h.size,E=f.getEncodedBits(w,y);let p,b;for(p=0;p<15;p++)b=(E>>p&1)===1,p<6?h.set(p,8,b,!0):p<8?h.set(p+1,8,b,!0):h.set(d-15+p,8,b,!0),p<8?h.set(8,d-p-1,b,!0):p<9?h.set(8,15-p-1+1,b,!0):h.set(8,15-p-1,b,!0);h.set(d-8,8,1,!0)}function I(h,w){const y=h.size;let d=-1,E=y-1,p=7,b=0;for(let m=y-1;m>0;m-=2)for(m===6&&m--;;){for(let A=0;A<2;A++)if(!h.isReserved(E,m-A)){let $=!1;b<w.length&&($=(w[b]>>>p&1)===1),h.set(E,m-A,$),p--,p===-1&&(b++,p=7)}if(E+=d,E<0||y<=E){E-=d,d=-d;break}}}function S(h,w,y){const d=new i;y.forEach(function(A){d.put(A.mode.bit,4),d.put(A.getLength(),v.getCharCountIndicator(A.mode,h)),A.write(d)});const E=t.getSymbolTotalCodewords(h),p=a.getTotalCodewordsCount(h,w),b=(E-p)*8;for(d.getLengthInBits()+4<=b&&d.put(0,4);d.getLengthInBits()%8!==0;)d.putBit(0);const m=(b-d.getLengthInBits())/8;for(let A=0;A<m;A++)d.put(A%2?17:236,8);return C(d,h,w)}function C(h,w,y){const d=t.getSymbolTotalCodewords(w),E=a.getTotalCodewordsCount(w,y),p=d-E,b=a.getBlocksCount(w,y),m=d%b,A=b-m,$=Math.floor(d/b),G=Math.floor(p/b),be=G+1,kt=$-G,ve=new l(kt);let ot=0;const X=new Array(b),Dt=new Array(b);let it=0;const Ce=new Uint8Array(h.buffer);for(let K=0;K<b;K++){const at=K<A?G:be;X[K]=Ce.slice(ot,ot+at),Dt[K]=ve.encode(X[K]),ot+=at,it=Math.max(it,at)}const st=new Uint8Array(d);let Ut=0,D,U;for(D=0;D<it;D++)for(U=0;U<b;U++)D<X[U].length&&(st[Ut++]=X[U][D]);for(D=0;D<kt;D++)for(U=0;U<b;U++)st[Ut++]=Dt[U][D];return st}function P(h,w,y,d){let E;if(Array.isArray(h))E=g.fromArray(h);else if(typeof h=="string"){let $=w;if(!$){const G=g.rawSplit(h);$=c.getBestVersionForData(G,y)}E=g.fromString(h,$||40)}else throw new Error("Invalid data");const p=c.getBestVersionForData(E,y);if(!p)throw new Error("The amount of data is too big to be stored in a QR Code");if(!w)w=p;else if(w<p)throw new Error(`
The chosen QR Code version cannot contain this amount of data.
Minimum version required to store current data is: `+p+`.
`);const b=S(w,y,E),m=t.getSymbolSize(w),A=new r(m);return u(A,w),T(A),M(A,w),B(A,y,0),w>=7&&_(A,w),I(A,b),isNaN(d)&&(d=s.getBestMask(A,B.bind(null,A,y))),s.applyMask(d,A),B(A,y,d),{modules:A,version:w,errorCorrectionLevel:y,maskPattern:d,segments:E}}return ct.create=function(w,y){if(typeof w>"u"||w==="")throw new Error("No input text");let d=e.M,E,p;return typeof y<"u"&&(d=e.from(y.errorCorrectionLevel,e.M),E=c.from(y.version),p=s.from(y.maskPattern),y.toSJISFunc&&t.setToSJISFunction(y.toSJISFunc)),P(w,E,d,p)},ct}var It={},Rt={},le;function ye(){return le||(le=1,(function(t){function e(i){if(typeof i=="number"&&(i=i.toString()),typeof i!="string")throw new Error("Color should be defined as hex string");let r=i.slice().replace("#","").split("");if(r.length<3||r.length===5||r.length>8)throw new Error("Invalid hex color: "+i);(r.length===3||r.length===4)&&(r=Array.prototype.concat.apply([],r.map(function(o){return[o,o]}))),r.length===6&&r.push("F","F");const n=parseInt(r.join(""),16);return{r:n>>24&255,g:n>>16&255,b:n>>8&255,a:n&255,hex:"#"+r.slice(0,6).join("")}}t.getOptions=function(r){r||(r={}),r.color||(r.color={});const n=typeof r.margin>"u"||r.margin===null||r.margin<0?4:r.margin,o=r.width&&r.width>=21?r.width:void 0,s=r.scale||4;return{width:o,scale:o?4:s,margin:n,color:{dark:e(r.color.dark||"#000000ff"),light:e(r.color.light||"#ffffffff")},type:r.type,rendererOpts:r.rendererOpts||{}}},t.getScale=function(r,n){return n.width&&n.width>=r+n.margin*2?n.width/(r+n.margin*2):n.scale},t.getImageWidth=function(r,n){const o=t.getScale(r,n);return Math.floor((r+n.margin*2)*o)},t.qrToImageData=function(r,n,o){const s=n.modules.size,a=n.modules.data,l=t.getScale(s,o),c=Math.floor((s+o.margin*2)*l),f=o.margin*l,v=[o.color.light,o.color.dark];for(let g=0;g<c;g++)for(let u=0;u<c;u++){let T=(g*c+u)*4,M=o.color.light;if(g>=f&&u>=f&&g<c-f&&u<c-f){const _=Math.floor((g-f)/l),B=Math.floor((u-f)/l);M=v[a[_*s+B]?1:0]}r[T++]=M.r,r[T++]=M.g,r[T++]=M.b,r[T]=M.a}}})(Rt)),Rt}var ce;function He(){return ce||(ce=1,(function(t){const e=ye();function i(n,o,s){n.clearRect(0,0,o.width,o.height),o.style||(o.style={}),o.height=s,o.width=s,o.style.height=s+"px",o.style.width=s+"px"}function r(){try{return document.createElement("canvas")}catch{throw new Error("You need to specify a canvas element")}}t.render=function(o,s,a){let l=a,c=s;typeof l>"u"&&(!s||!s.getContext)&&(l=s,s=void 0),s||(c=r()),l=e.getOptions(l);const f=e.getImageWidth(o.modules.size,l),v=c.getContext("2d"),g=v.createImageData(f,f);return e.qrToImageData(g.data,o,l),i(v,c,f),v.putImageData(g,0,0),c},t.renderToDataURL=function(o,s,a){let l=a;typeof l>"u"&&(!s||!s.getContext)&&(l=s,s=void 0),l||(l={});const c=t.render(o,s,l),f=l.type||"image/png",v=l.rendererOpts||{};return c.toDataURL(f,v.quality)}})(It)),It}var _t={},ue;function Ve(){if(ue)return _t;ue=1;const t=ye();function e(n,o){const s=n.a/255,a=o+'="'+n.hex+'"';return s<1?a+" "+o+'-opacity="'+s.toFixed(2).slice(1)+'"':a}function i(n,o,s){let a=n+o;return typeof s<"u"&&(a+=" "+s),a}function r(n,o,s){let a="",l=0,c=!1,f=0;for(let v=0;v<n.length;v++){const g=Math.floor(v%o),u=Math.floor(v/o);!g&&!c&&(c=!0),n[v]?(f++,v>0&&g>0&&n[v-1]||(a+=c?i("M",g+s,.5+u+s):i("m",l,0),l=0,c=!1),g+1<o&&n[v+1]||(a+=i("h",f),f=0)):l++}return a}return _t.render=function(o,s,a){const l=t.getOptions(s),c=o.modules.size,f=o.modules.data,v=c+l.margin*2,g=l.color.light.a?"<path "+e(l.color.light,"fill")+' d="M0 0h'+v+"v"+v+'H0z"/>':"",u="<path "+e(l.color.dark,"stroke")+' d="'+r(f,c,l.margin)+'"/>',T='viewBox="0 0 '+v+" "+v+'"',_='<svg xmlns="http://www.w3.org/2000/svg" '+(l.width?'width="'+l.width+'" height="'+l.width+'" ':"")+T+' shape-rendering="crispEdges">'+g+u+`</svg>
`;return typeof a=="function"&&a(null,_),_},_t}var de;function Ke(){if(de)return O;de=1;const t=Be(),e=ze(),i=He(),r=Ve();function n(o,s,a,l,c){const f=[].slice.call(arguments,1),v=f.length,g=typeof f[v-1]=="function";if(!g&&!t())throw new Error("Callback required as last argument");if(g){if(v<2)throw new Error("Too few arguments provided");v===2?(c=a,a=s,s=l=void 0):v===3&&(s.getContext&&typeof c>"u"?(c=l,l=void 0):(c=l,l=a,a=s,s=void 0))}else{if(v<1)throw new Error("Too few arguments provided");return v===1?(a=s,s=l=void 0):v===2&&!s.getContext&&(l=a,a=s,s=void 0),new Promise(function(u,T){try{const M=e.create(a,l);u(o(M,s,l))}catch(M){T(M)}})}try{const u=e.create(a,l);c(null,o(u,s,l))}catch(u){c(u)}}return O.create=e.create,O.toCanvas=n.bind(null,i.render),O.toDataURL=n.bind(null,i.renderToDataURL),O.toString=n.bind(null,function(o,s,a){return r.render(o,a)}),O}var Oe=Ke();const je=Ee(Oe);let N=null;function Je(){return N||(N=document.createElement("div"),N.className="modal",N.hidden=!0,N.innerHTML=`
    <div class="modal-backdrop" data-close="true"></div>
    <div class="modal-panel" role="dialog" aria-modal="true" aria-labelledby="qr-title">
      <header class="modal-header">
        <div class="modal-header__text">
          <h2 id="qr-title" class="modal-title">移动端下载</h2>
          <p class="modal-subtitle">使用手机扫描二维码或复制链接下载</p>
        </div>
        <button type="button" class="modal-close-icon" aria-label="关闭" data-close="true">
          <span aria-hidden="true">×</span>
        </button>
      </header>
      <div class="modal-body">
        <div class="modal-file-card">
          <span class="modal-file-label">文件</span>
          <span class="modal-file-name"></span>
        </div>
        <div class="qr-section">
          <div class="qr-wrap">
            <canvas class="qr-canvas"></canvas>
          </div>
          <p class="qr-hint">扫码后将在手机浏览器中打开下载</p>
        </div>
        <div class="modal-link-field">
          <label class="modal-link-label" for="qr-download-url">下载链接</label>
          <div class="link-input-row">
            <input
              id="qr-download-url"
              class="modal-link-input"
              type="text"
              readonly
            />
            <button type="button" class="btn btn-secondary copy-link-btn">复制</button>
          </div>
        </div>
      </div>
      <footer class="modal-footer">
        <button type="button" class="btn btn-secondary modal-close-btn" data-close="true">关闭</button>
      </footer>
    </div>`,document.body.appendChild(N),N.addEventListener("click",t=>{const e=t.target;if(e.closest(".copy-link-btn")){xe();return}e.closest("[data-close='true']")&&fe()}),window.addEventListener("keydown",t=>{t.key==="Escape"&&N&&!N.hidden&&fe()}),N)}async function xe(){const t=N;if(!t)return;const e=t.querySelector(".modal-link-input"),i=t.querySelector(".copy-link-btn");if(!e||!i)return;const r=e.value;if(r)try{await navigator.clipboard.writeText(r),i.textContent="已复制",window.setTimeout(()=>{i.textContent="复制"},1600)}catch{e.select(),document.execCommand("copy"),i.textContent="已复制",window.setTimeout(()=>{i.textContent="复制"},1600)}}function fe(){!N||N.hidden||(N.hidden=!0,document.body.classList.remove("modal-open"))}async function Ye(t,e){const i=Je(),r=i.querySelector(".modal-file-name"),n=i.querySelector(".modal-link-input"),o=i.querySelector(".qr-canvas"),s=i.querySelector(".copy-link-btn");!r||!n||!o||!s||(r.textContent=t,r.title=t,n.value=e,n.title=e,s.textContent="复制",await je.toCanvas(o,e,{width:168,margin:0,color:{dark:"#101828",light:"#ffffff"}}),i.hidden=!1,document.body.classList.add("modal-open"))}function Ge(t){return new URL(t,window.location.origin).href}function Qe(t){const e=t.reduce((s,a)=>s+a.size,0);if(e<=0)return"0 B";const i=["B","KB","MB","GB","TB"];let r=e,n=0;for(;r>=1024&&n<i.length-1;)r/=1024,n+=1;const o=r>=100||n===0?0:r>=10?1:2;return`${r.toFixed(o)} ${i[n]}`}function Ze(t){var i;const e=((i=t.split(".").pop())==null?void 0:i.toLowerCase())??"";return["pdf"].includes(e)?"pdf":["jpg","jpeg","png","gif","webp","svg","bmp"].includes(e)?"image":["mp4","mov","avi","mkv","webm"].includes(e)?"video":["mp3","wav","flac","aac","m4a"].includes(e)?"audio":["zip","rar","7z","tar","gz"].includes(e)?"archive":["doc","docx","txt","md","rtf"].includes(e)?"doc":["xls","xlsx","csv"].includes(e)?"sheet":["ppt","pptx"].includes(e)?"slide":"file"}const We=3e3;let L=null,R=null,j=null,Z=!1,rt=!1;function Xe(){const t="instant_share_viewer_id";let e=sessionStorage.getItem(t);return e||(typeof crypto<"u"&&typeof crypto.randomUUID=="function"?e=crypto.randomUUID():e=`viewer-${Date.now()}-${Math.random().toString(36).slice(2,10)}`,sessionStorage.setItem(t,e)),e}function tn(){const t=location.protocol==="https:"?"wss:":"ws:",e=new URLSearchParams({role:"viewer",device_id:Xe()});return`${t}//${location.host}/ws?${e.toString()}`}function en(){j!==null&&(clearTimeout(j),j=null)}function nn(){!Z||j!==null||(j=setTimeout(()=>{j=null,we()},We))}function rn(t){var i,r;let e;try{e=JSON.parse(t.data)}catch{return}if(e.type==="auth_ack"){e.code!==0&&((i=R==null?void 0:R.onError)==null||i.call(R,e.message??"WebSocket 鉴权失败"));return}if(e.type==="share.status"&&e.code===0&&e.data){rt=!0,R==null||R.onStatus(e.data);return}e.type==="error"&&e.code!==0&&((r=R==null?void 0:R.onError)==null||r.call(R,e.message??"WebSocket 连接异常"))}function we(){Z&&(L==null||L.close(),L=new WebSocket(tn()),L.addEventListener("message",rn),L.addEventListener("close",()=>{var t;Z&&rt&&((t=R==null?void 0:R.onError)==null||t.call(R,"连接已断开，正在重连…")),nn()}),L.addEventListener("error",()=>{L==null||L.close()}))}function on(t){return R=t,Z=!0,rt=!1,we(),()=>{Z=!1,R=null,rt=!1,en(),L==null||L.close(),L=null}}const F=new Set;let J=[],x=[],Y=!1,W="article";function sn(t){return t.articles.length>0?t.articles:t.article?[t.article]:[]}function q(t){return t.replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#39;")}function an(t){const e=new Set(t.map(i=>i.id));for(const i of F)e.has(i)||F.delete(i)}function ln(){const t=W==="file";return`
    <div
      class="share-mode-tabs ${Y?"share-mode-tabs--sharing":""} ${t?"share-mode-tabs--file":"share-mode-tabs--article"}"
      role="tablist"
      aria-label="分享类型"
    >
      <div class="share-mode-tabs__track">
        <div class="share-mode-tabs__slider" aria-hidden="true"></div>
        <button
          type="button"
          class="share-mode-tab ${t?"":"is-active"}"
          data-mode="article"
          role="tab"
          aria-selected="${t?"false":"true"}"
        >
          <span class="share-mode-tab__icon" aria-hidden="true">${cn()}</span>
          <span>分享文章</span>
        </button>
        <button
          type="button"
          class="share-mode-tab ${t?"is-active":""}"
          data-mode="file"
          role="tab"
          aria-selected="${t?"true":"false"}"
        >
          <span class="share-mode-tab__icon" aria-hidden="true">${un()}</span>
          <span>分享文件</span>
        </button>
      </div>
    </div>`}function cn(){return`
    <svg viewBox="0 0 16 16" width="15" height="15" fill="currentColor">
      <path d="M8 1.2 9.1 5.9 13.8 7 9.1 8.1 8 12.8 6.9 8.1 2.2 7 6.9 5.9 8 1.2Zm4.8 1.5.6 2.1 2.1.6-2.1.6-.6 2.1-.6-2.1-2.1-.6 2.1-.6.6-2.1ZM3.2 10.8l.4 1.4 1.4.4-1.4.4-.4 1.4-.4-1.4-1.4-.4 1.4-.4.4-1.4Z" />
    </svg>`}function un(){return`
    <svg viewBox="0 0 16 16" width="15" height="15" fill="currentColor">
      <path d="M4 1.5h5.2L12 4.3V13.5A1.5 1.5 0 0 1 10.5 15h-6A1.5 1.5 0 0 1 3 13.5v-11A1.5 1.5 0 0 1 4.5 1H4Zm5 0V5h3.5L9 1.5ZM5 7.25h6v1H5v-1Zm0 2.75h4.5v1H5v-1Z" />
    </svg>`}function dn(t){if(t.active){const e=[];return t.articles.length>0&&e.push(`${t.articles.length} 篇文章`),t.files.length>0&&e.push(`${t.files.length} 个文件 · ${Qe(t.files)}`),`
      <span class="status-indicator status-indicator--active">
        <span class="status-dot" aria-hidden="true"></span>
        分享进行中
      </span>
      <span class="status-meta">${e.length>0?e.join(" · "):"分享进行中"}</span>`}return`
    <span class="status-indicator status-indicator--idle">
      <span class="status-dot" aria-hidden="true"></span>
      等待分享
    </span>
    <span class="status-meta">发起者尚未开启分享</span>`}function fn(t){const e=t.title.trim()||"无标题",i=t.content.trim();return`
    <section class="article-panel">
      <div class="article-panel__header">
        <h2 class="article-panel__title">${q(e)}</h2>
        <button
          type="button"
          class="btn btn-ghost copy-article-btn"
          data-article-id="${q(t.id)}"
        >复制正文</button>
      </div>
      <div class="article-panel__body">${q(i).replaceAll(`
`,"<br />")}</div>
    </section>`}function hn(t){return`
    <div class="articles-panel">
      ${t.map(fn).join("")}
    </div>`}function gn(){return`
    <div class="empty-state">
      <p class="empty-state__title">暂无文章</p>
      <p class="empty-state__desc">发起者尚未发布文章，或当前没有标记为已分享的文章。</p>
    </div>`}function pn(){return`
    <div class="empty-state">
      <p class="empty-state__title">暂无文件</p>
      <p class="empty-state__desc">发起者尚未添加可下载的文件。</p>
    </div>`}function mn(t){if(t.length===0)return"";const e=t.filter(r=>F.has(r.id)).length;return`
    <div class="panel-toolbar">
      <label class="toolbar-select">
        <input
          type="checkbox"
          class="file-checkbox select-all-checkbox"
          ${t.length>0&&e===t.length?"checked":""}
          aria-label="全选文件"
        />
        <span>全选</span>
      </label>
      <span class="toolbar-divider" aria-hidden="true"></span>
      <span class="toolbar-summary">已选 ${e} / ${t.length}</span>
      <div class="toolbar-actions">
        <button
          type="button"
          class="btn btn-primary batch-download-btn"
          ${e===0?"disabled":""}
        >下载选中</button>
      </div>
    </div>`}function yn(t){const e=Ge(t.download_url),i=Ze(t.name),r=F.has(t.id)?"checked":"";return`
    <tr class="file-row">
      <td class="col-check">
        <input
          type="checkbox"
          class="file-checkbox row-checkbox"
          data-file-id="${q(t.id)}"
          ${r}
          aria-label="选择 ${q(t.name)}"
        />
      </td>
      <td class="col-name">
        <div class="file-cell">
          <span class="file-type file-type-${i}" aria-hidden="true">${i.toUpperCase()}</span>
          <div class="file-meta">
            <div class="file-name" title="${q(t.name)}">${q(t.name)}</div>
          </div>
        </div>
      </td>
      <td class="col-size">${q(t.size_text)}</td>
      <td class="col-actions">
        <button
          type="button"
          class="btn btn-ghost qr-btn"
          data-qr-name="${q(t.name)}"
          data-qr-url="${q(e)}"
        >二维码</button>
        <a class="btn btn-ghost" href="${q(t.download_url)}" download="${q(t.name)}">下载</a>
      </td>
    </tr>`}function wn(t){return`
    <div class="panel-list">
      ${mn(t)}
      <div class="table-wrap">
        <table class="file-table">
          <thead>
            <tr>
              <th class="col-check" scope="col"></th>
              <th class="col-name" scope="col">文件名</th>
              <th class="col-size" scope="col">大小</th>
              <th class="col-actions" scope="col">操作</th>
            </tr>
          </thead>
          <tbody>
            ${t.map(yn).join("")}
          </tbody>
        </table>
      </div>
    </div>`}function bn(t){return W==="article"?t.articles.length>0?hn(t.articles):gn():t.files.length>0?wn(t.files):pn()}function vn(){return W==="article"?`
      <div class="empty-state">
        <p class="empty-state__title">暂无可用文章</p>
        <p class="empty-state__desc">请在发起者桌面端开启分享后，通过本页面接收文章。</p>
      </div>`:`
    <div class="empty-state">
      <p class="empty-state__title">暂无可用文件</p>
      <p class="empty-state__desc">请在发起者桌面端开启分享后，通过本页面下载文件。</p>
    </div>`}function Cn(t){return`
    <div class="empty-state empty-state--error">
      <p class="empty-state__title">连接异常</p>
      <p class="empty-state__desc">${q(t)}</p>
      <p class="empty-state__hint">系统将自动重试连接，请确认与发起者处于同一局域网。</p>
    </div>`}function En(){return`
    <div class="empty-state">
      <p class="empty-state__title">正在连接服务</p>
      <p class="empty-state__desc">正在建立 WebSocket 连接并同步分享状态…</p>
    </div>`}function qt(t,e,i){return`
    <div class="app-shell">
      <header class="app-header">
        <div class="app-brand">
          <div class="app-brand__mark" aria-hidden="true">IS</div>
          <div>
            <div class="app-brand__title">Instant Share</div>
            <div class="app-brand__subtitle">文件与文章接收控制台</div>
          </div>
        </div>
        <div class="app-header__status">${t}</div>
      </header>
      <main class="app-main">
        <section class="panel">
          ${ln()}
          <div class="panel-body">${e}</div>
        </section>
      </main>
      <footer class="app-footer">局域网分享 · 仅限内网访问</footer>
    </div>`}function nt(t){an(t.files),J=t.files,x=sn(t),Y=t.active;const e={active:t.active,session_id:t.session_id,files:t.files,articles:x},i=t.active?bn(e):vn();return qt(dn(e),i)}function Bn(t){return Y=!1,J=[],x=[],qt('<span class="status-indicator status-indicator--error"><span class="status-dot" aria-hidden="true"></span>连接失败</span>',Cn(t))}function Sn(){return Y=!1,J=[],x=[],qt('<span class="status-indicator status-indicator--idle"><span class="status-dot" aria-hidden="true"></span>连接中</span>',En())}function An(t){return`/api/v1/share/files/batch/download?${new URLSearchParams({ids:t.join(",")}).toString()}`}function Tn(t){if(t.length===0)return;const e=document.createElement("a");e.href=An(t),e.rel="noopener",document.body.appendChild(e),e.click(),e.remove()}async function Mn(t,e){const i=x.find(r=>r.id===t);if(!(i!=null&&i.content))return Pt("暂无可复制的正文"),!1;try{await navigator.clipboard.writeText(i.content)}catch{try{const r=document.createElement("textarea");r.value=i.content,document.body.appendChild(r),r.select(),document.execCommand("copy"),r.remove()}catch{return Pt("复制失败，请手动选择正文复制"),!1}}if(Pt("正文已复制"),e){const r=e.textContent??"复制正文";e.textContent="已复制",window.setTimeout(()=>{e.textContent=r},1600)}return!0}let et=null;function Pt(t){let e=document.querySelector(".app-toast");e||(e=document.createElement("div"),e.className="app-toast",e.setAttribute("role","status"),e.setAttribute("aria-live","polite"),document.body.appendChild(e)),e.textContent=t,e.classList.add("is-visible"),et!==null&&window.clearTimeout(et),et=window.setTimeout(()=>{e==null||e.classList.remove("is-visible"),et=null},2e3)}function Nt(){return{active:Y,files:J,articles:x}}function In(t){t.addEventListener("click",e=>{const i=e.target,r=i.closest(".share-mode-tab");if(r!=null&&r.dataset.mode){const a=r.dataset.mode;a!==W&&(W=a,t.innerHTML=nt(Nt()));return}const n=i.closest(".copy-article-btn");if(n!=null&&n.dataset.articleId){Mn(n.dataset.articleId,n);return}const o=i.closest(".qr-btn");if(o){const a=o.dataset.qrName,l=o.dataset.qrUrl;a&&l&&Ye(a,l);return}const s=i.closest(".batch-download-btn");if(s&&!s.disabled){const a=J.filter(l=>F.has(l.id)).map(l=>l.id);Tn(a)}}),t.addEventListener("change",e=>{if(!Y)return;const i=e.target;if(i.classList.contains("select-all-checkbox")){const r=i;if(F.clear(),r.checked)for(const n of J)F.add(n.id);t.innerHTML=nt({...Nt(),active:!0});return}if(i.classList.contains("row-checkbox")){const r=i,n=r.dataset.fileId;if(!n)return;r.checked?F.add(n):F.delete(n),t.innerHTML=nt({...Nt(),active:!0})}})}function Rn(t){In(t),t.innerHTML=Sn();const e=on({onStatus:i=>{t.innerHTML=nt(i)},onError:i=>{t.innerHTML=Bn(i)}});window.addEventListener("beforeunload",()=>{e()})}const he=document.querySelector("#app");he&&Rn(he);
