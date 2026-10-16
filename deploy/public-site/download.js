// Draws the QR code of this page's own address (V1 checklist 6.4). It is
// built from the serving origin, so a printed or on-screen code keeps
// pointing at whichever domain hosts the site. The SVG is assembled with DOM
// calls and presentation attributes because the CSP allows no inline styles.
(function () {
  "use strict";

  var SVG_NS = "http://www.w3.org/2000/svg";
  // The four-module light border scanners need around the code.
  var QUIET_ZONE = 4;

  function svgElement(name, attributes) {
    var element = document.createElementNS(SVG_NS, name);
    Object.keys(attributes).forEach(function (key) {
      element.setAttribute(key, attributes[key]);
    });
    return element;
  }

  function render() {
    var target = document.getElementById("download-qr");
    var urlLabel = document.getElementById("download-url");
    if (!target || typeof window.qrcode !== "function") return;

    var url = window.location.origin + "/download";
    var qr = window.qrcode(0, "M");
    qr.addData(url);
    qr.make();

    var count = qr.getModuleCount();
    var size = count + QUIET_ZONE * 2;
    var path = "";
    for (var row = 0; row < count; row += 1) {
      for (var col = 0; col < count; col += 1) {
        if (qr.isDark(row, col)) {
          path += "M" + (col + QUIET_ZONE) + " " + (row + QUIET_ZONE) + "h1v1h-1z";
        }
      }
    }

    var svg = svgElement("svg", {
      viewBox: "0 0 " + size + " " + size,
      role: "img",
      "aria-label": "رمز QR لصفحة تحميل اعّرست",
      "shape-rendering": "crispEdges",
    });
    svg.appendChild(svgElement("rect", { width: size, height: size, fill: "#ffffff" }));
    svg.appendChild(svgElement("path", { d: path, fill: "#000000" }));

    target.replaceChildren(svg);
    if (urlLabel) urlLabel.textContent = url;
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", render);
  } else {
    render();
  }
})();
