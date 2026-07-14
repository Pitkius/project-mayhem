import { useCallback, useEffect, useMemo, useState } from 'react';
import { fetchNui, itemImageUrl } from '../nui';
import { CATEGORY_ICONS, IconCheck, IconWrench, IconX } from './icons';
import type { CraftPayload, CraftRecipe, CraftStartResult } from './types';
import './craft.css';

function levelLabel(recipe: CraftRecipe): string {
  if (recipe.isKit) return 'Rinkinys';
  if (recipe.level) return `${recipe.level} lygis`;
  return '';
}

export default function CraftApp() {
  const [open, setOpen] = useState(false);
  const [payload, setPayload] = useState<CraftPayload | null>(null);
  const [categoryId, setCategoryId] = useState<string | null>(null);
  const [recipeKey, setRecipeKey] = useState<string | null>(null);
  const [amount, setAmount] = useState(1);
  const [crafting, setCrafting] = useState(false);
  const [status, setStatus] = useState<{ type: 'idle' | 'error' | 'success'; text: string }>({
    type: 'idle',
    text: '',
  });

  const reset = useCallback(() => {
    setOpen(false);
    setPayload(null);
    setCategoryId(null);
    setRecipeKey(null);
    setAmount(1);
    setCrafting(false);
    setStatus({ type: 'idle', text: '' });
  }, []);

  const close = useCallback(() => {
    fetchNui('craftClose');
    reset();
  }, [reset]);

  useEffect(() => {
    const onMsg = (e: MessageEvent) => {
      const msg = e.data as { action?: string; payload?: CraftPayload };
      if (msg.action === 'openCraft' && msg.payload?.ok) {
        const p = msg.payload;
        setPayload(p);
        setCategoryId(p.categories?.[0]?.id ?? null);
        setRecipeKey(null);
        setAmount(1);
        setCrafting(false);
        setStatus({ type: 'idle', text: '' });
        setOpen(true);
        return;
      }
      if (msg.action === 'closeCraft') {
        reset();
      }
    };
    window.addEventListener('message', onMsg);
    return () => window.removeEventListener('message', onMsg);
  }, [reset]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        close();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, close]);

  const recipes = payload?.recipes ?? [];
  const categories = payload?.categories ?? [];
  const inventory = payload?.inventory ?? {};
  const labels = payload?.labels ?? {};
  const maxBatch = payload?.maxBatch ?? 10;

  const filteredRecipes = useMemo(
    () => recipes.filter((r) => r.categoryId === categoryId),
    [recipes, categoryId],
  );

  const selected = useMemo(
    () => recipes.find((r) => r.key === recipeKey) ?? null,
    [recipes, recipeKey],
  );

  useEffect(() => {
    if (!categoryId) return;
    if (selected && selected.categoryId === categoryId) return;
    const first = filteredRecipes[0];
    setRecipeKey(first?.key ?? null);
    setAmount(1);
  }, [categoryId, filteredRecipes, selected]);

  useEffect(() => {
    if (!selected) return;
    setAmount((a) => Math.max(1, Math.min(a, Math.max(1, selected.maxAmount || 1), maxBatch)));
  }, [selected, maxBatch]);

  const materialRows = useMemo(() => {
    if (!selected) return [];
    return selected.materials.map((m) => {
      const have = inventory[m.item] ?? 0;
      const need = m.need * amount;
      const ok = have >= need;
      const missing = ok ? 0 : need - have;
      const info = labels[m.item];
      return {
        item: m.item,
        label: info?.label ?? m.item,
        image: info?.image ?? 'box.png',
        have,
        need,
        ok,
        missing,
      };
    });
  }, [selected, amount, inventory, labels]);

  const canCraft = useMemo(() => {
    if (!selected || crafting) return false;
    if (amount < 1 || amount > maxBatch) return false;
    if ((selected.maxAmount ?? 0) < amount) return false;
    return materialRows.every((r) => r.ok);
  }, [selected, crafting, amount, maxBatch, materialRows]);

  const maxForSelected = selected ? Math.min(maxBatch, Math.max(0, selected.maxAmount ?? 0)) : 0;

  const handleCraft = async () => {
    if (!selected || !canCraft) return;
    setCrafting(true);
    setStatus({ type: 'idle', text: 'Gaminama…' });
    try {
      const res = await fetchNui<CraftStartResult>('craftStart', {
        recipeKey: selected.key,
        amount,
      });
      if (!res?.ok) {
        setStatus({ type: 'error', text: res?.message || 'Nepavyko pagaminti.' });
        return;
      }
      const refresh = await fetchNui<CraftPayload>('craftRefresh');
      if (refresh?.ok) {
        setPayload(refresh);
        const still = refresh.recipes?.find((r) => r.key === selected.key);
        if (still) setRecipeKey(still.key);
      }
      setStatus({ type: 'success', text: `Pagaminta: ${selected.label} ×${amount}` });
      setAmount(1);
    } catch {
      setStatus({ type: 'error', text: 'Ryšio klaida.' });
    } finally {
      setCrafting(false);
    }
  };

  if (!open || !payload) return null;

  const CatIcon = CATEGORY_ICONS[categoryId ?? 'other'] ?? IconWrench;
  const selectedCat = categories.find((c) => c.id === categoryId);

  return (
    <div className="craft-root">
      <div className="craft-backdrop" onClick={close} aria-hidden="true" />
      <div className="craft-shell" role="dialog" aria-modal="true" aria-label="Mechanikų crafting">
        <header className="craft-header">
          <div className="craft-header__brand">
            <div className="craft-header__logo">
              <IconWrench />
            </div>
            <div>
              <h1>{payload.title || 'Mechanikų dirbtuvės'}</h1>
              <p>{payload.subtitle || 'Performance dalių gamyba'}</p>
            </div>
          </div>
          <button type="button" className="craft-close" onClick={close} aria-label="Uždaryti">
            <IconX />
          </button>
        </header>

        <div className="craft-body">
          <aside className="craft-categories">
            <div className="craft-categories__label">Kategorijos</div>
            {categories.map((cat) => {
              const Icon = CATEGORY_ICONS[cat.id] ?? IconWrench;
              const active = cat.id === categoryId;
              return (
                <button
                  key={cat.id}
                  type="button"
                  className={`craft-cat-btn${active ? ' active' : ''}`}
                  onClick={() => setCategoryId(cat.id)}
                >
                  <span className="craft-cat-btn__icon">
                    <Icon />
                  </span>
                  <span className="craft-cat-btn__text">
                    <b>{cat.label}</b>
                    <span>{cat.desc}</span>
                  </span>
                </button>
              );
            })}
          </aside>

          <section className="craft-recipes">
            <div className="craft-recipes__head">
              <h2>Galimi patobulinimai</h2>
            </div>
            {filteredRecipes.length ? (
              <div className="craft-recipes__grid">
                {filteredRecipes.map((recipe) => {
                  const lvl = levelLabel(recipe);
                  const active = recipe.key === recipeKey;
                  return (
                    <button
                      key={recipe.key}
                      type="button"
                      className={`craft-recipe-card${active ? ' active' : ''}`}
                      onClick={() => {
                        setRecipeKey(recipe.key);
                        setAmount(1);
                        setStatus({ type: 'idle', text: '' });
                      }}
                    >
                      <img
                        className="craft-recipe-card__img"
                        src={itemImageUrl(recipe.image)}
                        alt=""
                        loading="lazy"
                      />
                      <div className="craft-recipe-card__body">
                        <b>{recipe.label}</b>
                        <div className="craft-recipe-card__meta">
                          {lvl || recipe.description?.slice(0, 48) || 'Performance dalis'}
                        </div>
                      </div>
                      {lvl ? <span className="craft-recipe-card__badge">{lvl}</span> : null}
                    </button>
                  );
                })}
              </div>
            ) : (
              <div className="craft-empty">Šioje kategorijoje nėra receptų.</div>
            )}
          </section>

          <aside className="craft-detail">
            {selected ? (
              <>
                <div className="craft-detail__hero">
                  <img src={itemImageUrl(selected.image)} alt="" />
                  <h3>{selected.label}</h3>
                  <div className="sub">
                    {selectedCat?.label ?? ''}
                    {levelLabel(selected) ? ` · ${levelLabel(selected)}` : ''}
                  </div>
                </div>
                {selected.description ? (
                  <p className="craft-detail__desc">{selected.description}</p>
                ) : null}

                <div className="craft-mats">
                  <h4>Reikalingos medžiagos</h4>
                  {materialRows.map((row) => (
                    <div key={row.item} className="craft-mat-row">
                      <img src={itemImageUrl(row.image)} alt="" loading="lazy" />
                      <div className="craft-mat-row__info">
                        <b>{row.label}</b>
                        <span>
                          Turima: {row.have} · Reikia: {row.need}
                          {!row.ok ? ` · Trūksta: ${row.missing}` : ''}
                        </span>
                      </div>
                      <div className={`craft-mat-row__status ${row.ok ? 'ok' : 'bad'}`}>
                        {row.have} / {row.need}
                      </div>
                      <span className={`craft-mat-row__icon ${row.ok ? 'ok' : 'bad'}`}>
                        {row.ok ? <IconCheck /> : <IconX strokeWidth={2} />}
                      </span>
                    </div>
                  ))}
                </div>

                <div className="craft-qty">
                  <label>Kiekis</label>
                  <div className="craft-qty__controls">
                    <button
                      type="button"
                      disabled={crafting || amount <= 1}
                      onClick={() => setAmount((a) => Math.max(1, a - 1))}
                    >
                      −
                    </button>
                    <span className="craft-qty__value">{amount}</span>
                    <button
                      type="button"
                      disabled={crafting || amount >= maxForSelected}
                      onClick={() => setAmount((a) => Math.min(maxForSelected, a + 1))}
                    >
                      +
                    </button>
                    <button
                      type="button"
                      className="craft-qty__max"
                      disabled={crafting || maxForSelected < 1}
                      onClick={() => setAmount(Math.max(1, maxForSelected))}
                    >
                      MAX
                    </button>
                  </div>
                </div>

                <button
                  type="button"
                  className="craft-submit"
                  disabled={!canCraft}
                  onClick={handleCraft}
                >
                  {crafting ? (
                    <span className="craft-spinner" aria-hidden="true" />
                  ) : (
                    <CatIcon />
                  )}
                  {crafting ? 'Gaminama…' : 'Craftinti'}
                </button>
                <div
                  className={`craft-status${
                    status.type === 'error' ? ' error' : status.type === 'success' ? ' success' : ''
                  }`}
                >
                  {status.text}
                </div>
              </>
            ) : (
              <div className="craft-empty">Pasirinkite dalį gamybai.</div>
            )}
          </aside>
        </div>
      </div>
    </div>
  );
}
