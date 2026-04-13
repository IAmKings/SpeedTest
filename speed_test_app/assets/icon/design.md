# SpeedTest App Icon Design

## Design Concept
- **Style**: Android Studios style - geometric, minimal, modern
- **Theme**: Tech blue gradient with speed motif
- **Background**: Rounded square with blue gradient (#1565C0 → #42A5F5)
- **Foreground**: Simple speedometer/gauge with needle pointing to high speed

## Visual Elements
1. Rounded square container with diagonal gradient
2. Semi-circular speedometer arc
3. Speed needle pointing to ~80% (fast speed)
4. Small speed ticks around the arc

## Colors
- Background Start: #1565C0 (Blue 800)
- Background End: #42A5F5 (Blue 400)
- Arc Color: #90CAF9 (Blue 200)
- Needle Color: #FFFFFF (White)
- Tick Color: #BBDEFB (Blue 100)

## SVG Structure
```svg
<svg viewBox="0 0 512 512">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1565C0"/>
      <stop offset="100%" stop-color="#42A5F5"/>
    </linearGradient>
  </defs>
  <rect x="32" y="32" width="448" height="448" rx="90" fill="url(#bg)"/>
  <!-- Speedometer arc -->
  <!-- Speed needle -->
</svg>
```
