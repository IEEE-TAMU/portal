// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/ieee_tamu_portal"
import topbar from "../vendor/topbar"

let Hooks = {...colocatedHooks}

// Integrated QR scanner hook for admin check-in
Hooks.QRScanner = {
  mounted() {
    // Lazy import to keep initial bundle smaller
    import('qr-scanner').then(mod => {
      const QrScanner = mod.default
      const video = document.getElementById('qr-video')
      if(!video) return

      let lastText = null
      const scanResult = (result) => {
        const text = result?.data || result
        if(!text || text === lastText) return
        lastText = text
        this.pushEvent('qr_scanned', {content: text})
      }

      const scanner = new QrScanner(video, scanResult, { returnDetailedScanResult: true })
      this.scanner = scanner

      const flashBtn = document.getElementById('toggle-flash')
      const cameraSelect = document.getElementById('camera-select')

      const updateFlashAvailability = () => {
        if(!flashBtn) return
        scanner.hasFlash().then(supported => {
          if(!supported) {
            flashBtn.disabled = true
            flashBtn.classList.add('opacity-50','cursor-not-allowed')
            flashBtn.classList.remove('bg-yellow-600')
            flashBtn.classList.add('bg-gray-600')
            flashBtn.textContent = 'Flash N/A'
          } else {
            flashBtn.disabled = false
            flashBtn.classList.remove('opacity-50','cursor-not-allowed')
            const on = scanner.isFlashOn()
            flashBtn.classList.toggle('bg-yellow-600', on)
            flashBtn.classList.toggle('bg-gray-600', !on)
            flashBtn.textContent = on ? 'Flash On' : 'Flash Off'
          }
        }).catch(() => {/* ignore */})
      }

      // Start scanner first, then enumerate cameras and configure preferred one.
      scanner.start()
        .then(() => QrScanner.listCameras(true))
        .then(cameras => {
          if(cameraSelect) {
            cameraSelect.innerHTML = ''
            cameras.forEach(c => {
              const opt = document.createElement('option')
              opt.value = c.id
              opt.textContent = c.label || c.id
              cameraSelect.appendChild(opt)
            })
            const back = cameras.find(c => /back|rear|environment/i.test(c.label))
            if(back) {
              scanner.setCamera(back.id).then(updateFlashAvailability)
              cameraSelect.value = back.id
            } else {
              updateFlashAvailability()
            }
          } else {
            updateFlashAvailability()
          }
        })
        .catch(() => { /* start failed (permission denied?) */ })

      cameraSelect?.addEventListener('change', e => {
        const id = e.target.value
        scanner.setCamera(id).then(() => {
          // After camera switch, update flash availability/state
          updateFlashAvailability()
        })
      })

      flashBtn?.addEventListener('click', () => {
        scanner.toggleFlash()
          .then(() => updateFlashAvailability())
          .catch(() => {/* ignore toggle errors */})
      })

      this.handleEvent('perform_checkin', ({member_id}) => {
        // Call existing endpoint; controller responds to GET
        fetch(`/admin/check-in?member_id=${encodeURIComponent(member_id)}`, {credentials: 'same-origin'})
          .then(r => {
            const ok = r.status === 201
            this.pushEvent('checkin_response', {ok, member_id})
          })
          .catch(() => this.pushEvent('checkin_response', {ok: false, member_id}))
          .finally(() => { setTimeout(()=> { lastText = null }, 1200) })
      })

      this.el.addEventListener('click', e => {
        if(e.target && e.target.id === 'restart-scan') {
          lastText = null
        }
      })
    })
  },
  destroyed() { this.scanner && this.scanner.stop() }
}

let Uploaders = {};
Uploaders.S3 = function (entries, onViewError) {
  entries.forEach((entry) => {
    let { url } = entry.meta;
    let xhr = new XMLHttpRequest();

    onViewError(() => xhr.abort());

    xhr.onload = () =>
      xhr.status >= 200 && xhr.status < 300
        ? entry.progress(100)
        : entry.error();

    xhr.onerror = () => entry.error();
    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        let percent = Math.round((event.loaded / event.total) * 100);
        if (percent < 100) {
          entry.progress(percent);
        }
      }
    });

    xhr.open("PUT", url, true);
    xhr.setRequestHeader("credentials", "same-origin parameter");
    xhr.send(entry.file);
  });
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  uploaders: Uploaders,
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

