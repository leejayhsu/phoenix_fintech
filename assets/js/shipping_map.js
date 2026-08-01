import * as maplibregl from "maplibre-gl"

const routeFeature = route => ({
  type: "Feature",
  properties: {},
  geometry: {
    type: "LineString",
    coordinates: route.geometry,
  },
})

const portsFeatureCollection = route => ({
  type: "FeatureCollection",
  features: route.ports.map(port => ({
    type: "Feature",
    properties: {
      name: port.name,
      country: port.country,
      role: port.role,
    },
    geometry: {
      type: "Point",
      coordinates: port.coordinates,
    },
  })),
})

const mapColor = name => {
  const color = getComputedStyle(document.documentElement)
    .getPropertyValue(`--color-${name}`)
    .trim()
  const canvas = document.createElement("canvas")
  canvas.width = 1
  canvas.height = 1

  const context = canvas.getContext("2d")
  context.fillStyle = color
  context.fillRect(0, 0, 1, 1)

  const [red, green, blue, alpha] = context.getImageData(0, 0, 1, 1).data
  return `rgba(${red}, ${green}, ${blue}, ${alpha / 255})`
}

const arrowImage = color => {
  const canvas = document.createElement("canvas")
  canvas.width = 32
  canvas.height = 32

  const context = canvas.getContext("2d")
  context.fillStyle = color
  context.beginPath()
  context.moveTo(7, 7)
  context.lineTo(25, 16)
  context.lineTo(7, 25)
  context.lineTo(12, 16)
  context.closePath()
  context.fill()

  return context.getImageData(0, 0, canvas.width, canvas.height)
}

const ShippingMap = {
  mounted() {
    this.route = JSON.parse(this.el.dataset.route)
    this.map = new maplibregl.Map({
      container: this.el,
      style: {
        version: 8,
        glyphs: "https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf",
        sources: {
          "world-basemap": {
            type: "raster",
            tiles: ["https://tiles.openfreemap.org/natural_earth/ne2sr/{z}/{x}/{y}.png"],
            tileSize: 256,
            maxzoom: 6,
            attribution: "OpenFreeMap · OpenStreetMap",
          },
        },
        layers: [
          {
            id: "world-basemap",
            type: "raster",
            source: "world-basemap",
          },
        ],
      },
      center: [35, -10],
      zoom: 1.3,
      attributionControl: false,
    })

    this.map.addControl(new maplibregl.NavigationControl({showCompass: false}), "top-right")
    this.map.addControl(
      new maplibregl.AttributionControl({compact: true}),
      "bottom-right",
    )

    this.map.on("load", () => {
      this.setupRouteLayers()
      this.fitRoute(this.route)
      this.el.querySelector(".loading")?.parentElement?.remove()
    })

    this.handleEvent("route_changed", route => {
      this.route = route
      if (this.map.getSource("freight-route")) this.drawRoute(route)
    })
  },

  destroyed() {
    this.map?.remove()
  },

  setupRouteLayers() {
    const primary = mapColor("primary")
    const accent = mapColor("accent")
    const primaryContent = mapColor("primary-content")

    this.map.addImage("route-arrow", arrowImage(primaryContent), {pixelRatio: 2})
    this.map.addSource("freight-route", {
      type: "geojson",
      data: routeFeature(this.route),
    })
    this.map.addSource("freight-ports", {
      type: "geojson",
      data: portsFeatureCollection(this.route),
    })

    this.map.addLayer({
      id: "freight-route-shadow",
      type: "line",
      source: "freight-route",
      paint: {
        "line-color": "rgba(0, 0, 0, 0.18)",
        "line-width": 8,
        "line-blur": 3,
      },
    })
    this.map.addLayer({
      id: "freight-route-line",
      type: "line",
      source: "freight-route",
      paint: {
        "line-color": primary,
        "line-width": 4,
      },
    })
    this.map.addLayer({
      id: "freight-route-arrows",
      type: "symbol",
      source: "freight-route",
      layout: {
        "symbol-placement": "line",
        "symbol-spacing": 100,
        "icon-image": "route-arrow",
        "icon-size": 0.8,
        "icon-allow-overlap": true,
        "icon-rotation-alignment": "map",
      },
    })
    this.map.addLayer({
      id: "freight-ports-circles",
      type: "circle",
      source: "freight-ports",
      paint: {
        "circle-color": ["match", ["get", "role"], "Transshipment", accent, primary],
        "circle-radius": ["match", ["get", "role"], "Transshipment", 6, 8],
        "circle-stroke-color": "#ffffff",
        "circle-stroke-width": 3,
      },
    })
    this.map.addLayer({
      id: "freight-ports-labels",
      type: "symbol",
      source: "freight-ports",
      layout: {
        "text-field": ["get", "name"],
        "text-size": 12,
        "text-font": ["Noto Sans Regular"],
        "text-offset": [0, 1.35],
        "text-anchor": "top",
      },
      paint: {
        "text-color": "#1f2937",
        "text-halo-color": "#ffffff",
        "text-halo-width": 2,
      },
    })

    this.map.on("click", "freight-ports-circles", event => {
      const feature = event.features?.[0]
      if (!feature) return

      const content = document.createElement("div")
      const title = document.createElement("strong")
      const detail = document.createElement("div")
      content.style.color = "#1f2937"
      title.textContent = feature.properties.name
      detail.textContent = `${feature.properties.role} · ${feature.properties.country}`
      detail.className = "text-sm"
      content.append(title, detail)

      new maplibregl.Popup({offset: 12})
        .setLngLat(feature.geometry.coordinates)
        .setDOMContent(content)
        .addTo(this.map)
    })
    this.map.on("mouseenter", "freight-ports-circles", () => {
      this.map.getCanvas().style.cursor = "pointer"
    })
    this.map.on("mouseleave", "freight-ports-circles", () => {
      this.map.getCanvas().style.cursor = ""
    })
  },

  drawRoute(route) {
    this.map.getSource("freight-route").setData(routeFeature(route))
    this.map.getSource("freight-ports").setData(portsFeatureCollection(route))

    this.fitRoute(route)
  },

  fitRoute(route) {
    const padding = this.el.clientWidth < 640 ? 24 : 60
    const bounds = route.geometry.reduce(
      (currentBounds, coordinate) => currentBounds.extend(coordinate),
      new maplibregl.LngLatBounds(route.geometry[0], route.geometry[0]),
    )

    this.map.fitBounds(bounds, {
      padding: {top: padding, right: padding, bottom: padding, left: padding},
      duration: 0,
      maxZoom: 4,
    })
  },
}

export default ShippingMap
