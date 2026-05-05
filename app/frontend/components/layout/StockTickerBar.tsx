import { useEffect, useRef } from "react"

interface Waypoint {
  x: number
  y: number
}

interface LineConfig {
  yWaypoints: Waypoint[]
  color: string
  width: number
  glowRadius: number
  minY: number
  maxY: number
}

const X_RATIOS = [
  0, 0.07, 0.13, 0.19, 0.25, 0.30, 0.35, 0.40,
  0.45, 0.50, 0.55, 0.61, 0.67, 0.74, 0.81, 0.88, 0.94, 1.0
]

const LINE_CONFIGS: Omit<LineConfig, "yWaypoints">[] = [
  { color: "109, 40, 217", width: 2.0, glowRadius: 12, minY: 4, maxY: 82 },
  { color: "37, 99, 235", width: 1.5, glowRadius: 10, minY: 4, maxY: 58 },
  { color: "147, 197, 253", width: 1.5, glowRadius: 10, minY: 28, maxY: 86 },
]

function generateYWaypoints(canvasWidth: number, minY: number, maxY: number): Waypoint[] {
  const range = maxY - minY
  const points: Waypoint[] = []
  let y = minY + range * (0.3 + Math.random() * 0.4)
  let lastDir = Math.random() > 0.5 ? 1 : -1
  let consecutiveSameDir = 0

  for (let i = 0; i < X_RATIOS.length; i++) {
    points.push({ x: X_RATIOS[i] * canvasWidth, y: Math.max(minY, Math.min(maxY, y)) })
    if (i < X_RATIOS.length - 1) {
      let dir: number
      if (consecutiveSameDir >= 1) {
        dir = Math.random() < 0.70 ? -lastDir : lastDir
      } else {
        dir = Math.random() > 0.5 ? 1 : -1
      }
      if (dir === lastDir) consecutiveSameDir++
      else consecutiveSameDir = 0
      lastDir = dir

      const isCrashOrSpike = Math.random() < 0.30
      const stepFraction = isCrashOrSpike
        ? 0.50 + Math.random() * 0.30
        : 0.20 + Math.random() * 0.25
      const step = stepFraction * range
      y += dir * step
      if (y < minY) { y = minY + (minY - y) * 0.3; lastDir = 1 }
      if (y > maxY) { y = maxY - (y - maxY) * 0.3; lastDir = -1 }
    }
  }
  return points
}

function getVelocity(progress: number): number {
  const BASE_SPEED = 0.004
  const EASE_ZONE = 0.12
  const edgeDist = Math.min(progress, 1 - progress)
  if (edgeDist < EASE_ZONE) {
    const t = edgeDist / EASE_ZONE
    const eased = t * t * (3 - 2 * t)
    return BASE_SPEED * (0.04 + 0.96 * eased)
  }
  return BASE_SPEED
}

function interpolate(waypoints: Waypoint[], progress: number): Waypoint {
  const n = waypoints.length - 1
  const scaled = progress * n
  const idx = Math.min(Math.floor(scaled), n - 1)
  const t = scaled - idx
  const a = waypoints[idx]
  const b = waypoints[idx + 1]
  return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t }
}

function drawLine(
  ctx: CanvasRenderingContext2D,
  canvas: HTMLCanvasElement,
  line: LineConfig,
  xProgress: number,
  direction: number
) {
  const TRAIL = 0.40
  let trailFrom: number, trailTo: number
  if (direction === 1) {
    trailFrom = Math.max(0, xProgress - TRAIL)
    trailTo = xProgress
  } else {
    trailFrom = xProgress
    trailTo = Math.min(1, xProgress + TRAIL)
  }

  const steps = 300
  for (let i = 0; i < steps; i++) {
    const t1 = trailFrom + (i / steps) * (trailTo - trailFrom)
    const t2 = trailFrom + ((i + 1) / steps) * (trailTo - trailFrom)
    const p1 = interpolate(line.yWaypoints, t1)
    const p2 = interpolate(line.yWaypoints, t2)
    const distFromHead = direction === 1 ? (xProgress - t2) / TRAIL : (t1 - xProgress) / TRAIL
    const alpha = Math.pow(Math.max(0, 1 - distFromHead), 1.8)

    ctx.beginPath()
    ctx.moveTo(p1.x, p1.y)
    ctx.lineTo(p2.x, p2.y)
    ctx.strokeStyle = `rgba(${line.color}, ${alpha})`
    ctx.lineWidth = line.width
    ctx.lineJoin = "round"
    ctx.stroke()
  }

  const head = interpolate(line.yWaypoints, xProgress)
  const edgeMargin = canvas.width * 0.10
  const edgeFade = Math.min(head.x / edgeMargin, (canvas.width - head.x) / edgeMargin)
  const headAlpha = Math.max(0, Math.min(1, edgeFade))

  const glow = ctx.createRadialGradient(head.x, head.y, 0, head.x, head.y, line.glowRadius)
  glow.addColorStop(0, `rgba(${line.color}, ${headAlpha})`)
  glow.addColorStop(0.4, `rgba(${line.color}, ${headAlpha * 0.35})`)
  glow.addColorStop(1, `rgba(${line.color}, 0)`)
  ctx.fillStyle = glow
  ctx.beginPath()
  ctx.arc(head.x, head.y, line.glowRadius, 0, Math.PI * 2)
  ctx.fill()

  ctx.fillStyle = `rgba(${line.color}, ${headAlpha})`
  ctx.beginPath()
  ctx.arc(head.x, head.y, 3, 0, Math.PI * 2)
  ctx.fill()
}

export default function StockTickerBar() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const xProgressRef = useRef(0)
  const directionRef = useRef(1)
  const linesRef = useRef<LineConfig[]>(
    LINE_CONFIGS.map((cfg) => ({ ...cfg, yWaypoints: [] }))
  )
  const rafRef = useRef<number | null>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext("2d")
    if (!ctx) return

    canvas.width = window.innerWidth
    canvas.height = 90
    linesRef.current.forEach((line) => {
      line.yWaypoints = generateYWaypoints(canvas.width, line.minY, line.maxY)
    })
    xProgressRef.current = 0
    directionRef.current = 1

    const animate = () => {
      rafRef.current = requestAnimationFrame(animate)
      if (typeof document !== "undefined" && document.visibilityState === "hidden") {
        return
      }

      const vel = getVelocity(xProgressRef.current) * directionRef.current
      xProgressRef.current = Math.max(0, Math.min(1, xProgressRef.current + vel))

      if (xProgressRef.current >= 1.0) {
        directionRef.current = -1
        linesRef.current.forEach((line) => {
          line.yWaypoints = generateYWaypoints(canvas.width, line.minY, line.maxY)
        })
      }
      if (xProgressRef.current <= 0.0) {
        directionRef.current = 1
        linesRef.current.forEach((line) => {
          line.yWaypoints = generateYWaypoints(canvas.width, line.minY, line.maxY)
        })
      }

      ctx.clearRect(0, 0, canvas.width, canvas.height)
      linesRef.current.forEach((line) => {
        drawLine(ctx, canvas, line, xProgressRef.current, directionRef.current)
      })
    }

    rafRef.current = requestAnimationFrame(animate)

    const onResize = () => {
      canvas.width = window.innerWidth
      canvas.height = 90
      linesRef.current.forEach((line) => {
        line.yWaypoints = generateYWaypoints(canvas.width, line.minY, line.maxY)
      })
    }
    window.addEventListener("resize", onResize)

    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current)
      window.removeEventListener("resize", onResize)
    }
  }, [])

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        background: "#0A0E1A",
        overflow: "hidden",
        maskImage: "linear-gradient(to right, transparent 0%, black 10%, black 90%, transparent 100%)",
        WebkitMaskImage: "linear-gradient(to right, transparent 0%, black 10%, black 90%, transparent 100%)",
      }}
    >
      <canvas
        ref={canvasRef}
        style={{ display: "block", width: "100%", height: "100%", pointerEvents: "none" }}
        aria-hidden
      />
    </div>
  )
}
