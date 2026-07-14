import type { SVGProps } from 'react';

type IconProps = SVGProps<SVGSVGElement>;

const base = { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 1.8 } as const;

export function IconEngine(props: IconProps) {
  return (
    <svg {...base} {...props}>
      <path d="M7 7h3l1-2h2l1 2h3v8h-3l-1 2h-2l-1-2H7V7z" />
      <path d="M9 11h6M12 9v4" />
    </svg>
  );
}

export function IconTurbo(props: IconProps) {
  return (
    <svg {...base} {...props}>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M19.1 4.9 17 7M7 17l-2.1 2.1" />
    </svg>
  );
}

export function IconTransmission(props: IconProps) {
  return (
    <svg {...base} {...props}>
      <circle cx="7" cy="7" r="2.5" />
      <circle cx="17" cy="7" r="2.5" />
      <circle cx="12" cy="17" r="2.5" />
      <path d="M9 7h6M10.5 9.5 12 14.5M13.5 9.5 12 14.5" />
    </svg>
  );
}

export function IconSuspension(props: IconProps) {
  return (
    <svg {...base} {...props}>
      <path d="M6 18h12M8 18V8l4-4 4 4v10" />
      <path d="M12 4v4M9 10h6" />
    </svg>
  );
}

export function IconBrakes(props: IconProps) {
  return (
    <svg {...base} {...props}>
      <circle cx="12" cy="12" r="7" />
      <circle cx="12" cy="12" r="2.5" />
      <path d="M12 5v2M12 17v2M5 12h2M17 12h2" />
    </svg>
  );
}

export function IconArmor(props: IconProps) {
  return (
    <svg {...base} {...props}>
      <path d="M12 3 4 7v6c0 5 3.5 8 8 8s8-3 8-8V7l-8-4z" />
    </svg>
  );
}

export function IconRepair(props: IconProps) {
  return (
    <svg {...base} {...props}>
      <path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.5 2.5-2.5-2.5 2.5-2.5z" />
    </svg>
  );
}

export function IconWrench(props: IconProps) {
  return (
    <svg {...base} {...props}>
      <path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.5 2.5-2.5-2.5 2.5-2.5z" />
    </svg>
  );
}

export function IconCheck(props: IconProps) {
  return (
    <svg {...base} strokeWidth={2} {...props}>
      <path d="M5 12l5 5L20 7" />
    </svg>
  );
}

export function IconX(props: IconProps) {
  return (
    <svg {...base} strokeWidth={2} {...props}>
      <path d="M6 6l12 12M18 6 6 18" />
    </svg>
  );
}

export const CATEGORY_ICONS: Record<string, (p: IconProps) => JSX.Element> = {
  engine: IconEngine,
  turbo: IconTurbo,
  transmission: IconTransmission,
  suspension: IconSuspension,
  brakes: IconBrakes,
  armor: IconArmor,
  repair_kits: IconRepair,
  other: IconWrench,
};
