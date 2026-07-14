declare function GetParentResourceName(): string;

export function getResourceName(): string {
  if (typeof GetParentResourceName === 'function') {
    return GetParentResourceName();
  }
  return 'mrp_mechanic';
}

export async function fetchNui<T = unknown>(event: string, data: Record<string, unknown> = {}): Promise<T> {
  const res = await fetch(`https://${getResourceName()}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  return res.json() as Promise<T>;
}

export function itemImageUrl(image: string): string {
  return `nui://qb-inventory/html/images/${image}`;
}
