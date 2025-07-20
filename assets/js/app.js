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
import topbar from "../vendor/topbar"

let Hooks = {}
Hooks.Flash = {
  mounted() {
    const time = 3000;
    let hide = () => liveSocket.execJS(this.el, this.el.getAttribute("phx-click"))
    this.timer = setTimeout(() => hide(), time)
    this.el.addEventListener("phx:hide-start", () => clearTimeout(this.timer))
    this.el.addEventListener("mouseover", () => {
      clearTimeout(this.timer)
    })
    this.el.addEventListener("mouseout", () => {
      this.timer = setTimeout(() => hide(), time)
    })
  },
  destroyed() { clearTimeout(this.timer) }
}
Hooks.PhoneNumber = {
  mounted() {
    let func = e => {
      const value = this.el.value.replace(/\D/g, "")
      this.el.value = value
      match = value.match(/^(\d{3})(\d{1,3})?(\d{1,4})?$/)
      if (match) {
        this.el.value = match[1] + (match[2] ? "-" + match[2] : "") + (match[3] ? "-" + match[3] : "")
      }
    }
    this.el.addEventListener("input", func)
    func()
  }
}
Hooks.AutoUpcase = {
  mounted() {
    let func = e => {
      const value = this.el.value.toUpperCase()
      this.el.value = value
    }
    this.el.addEventListener("input", func)
    func()
  }
}
Hooks.CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      const code = this.el.getAttribute("phx-value-code")
      navigator.clipboard.writeText(code).then(() => {
        // Toggle visibility of clipboard and check icons
        const clipboardIcon = this.el.querySelector('[class*="hero-clipboard"]')
        const checkIcon = this.el.querySelector('[class*="hero-check"]')
        
        if (clipboardIcon && checkIcon) {
          clipboardIcon.classList.add('hidden')
          checkIcon.classList.remove('hidden')
          
          setTimeout(() => {
            clipboardIcon.classList.remove('hidden')
            checkIcon.classList.add('hidden')
          }, 1000)
        }
      }).catch(() => {
        // Fallback for browsers that don't support clipboard API
        const textArea = document.createElement("textarea")
        textArea.value = code
        document.body.appendChild(textArea)
        textArea.select()
        document.execCommand("copy")
        document.body.removeChild(textArea)
        
        // Still show the visual feedback even with fallback
        const clipboardIcon = this.el.querySelector('[class*="hero-clipboard"]')
        const checkIcon = this.el.querySelector('[class*="hero-check"]')
        
        if (clipboardIcon && checkIcon) {
          clipboardIcon.classList.add('hidden')
          checkIcon.classList.remove('hidden')
          
          setTimeout(() => {
            clipboardIcon.classList.remove('hidden')
            checkIcon.classList.add('hidden')
          }, 1000)
        }
      })
    })
  }
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

