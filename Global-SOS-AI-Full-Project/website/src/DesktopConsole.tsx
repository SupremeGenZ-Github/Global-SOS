type Service = {id:string; name:string; region?:string|null; channels:{kind:string;value:string}[]};

export function DesktopConsole({country, services, online, contacts, onSOS, onNavigate, t}: {
  t: (label: string) => string; country: string; services: Service[]; online: boolean; contacts: number;
  onSOS: () => void; onNavigate: (tab:string) => void;
}) {
  return <section className="desktop-console" aria-label="Desktop safety console">
    <div className="console-hero">
      <div><p className="eyebrow">{t('Home')}</p><h1>{t('Help is closer than you think.')}</h1><p>{t('Find the right service. Make the next step clear.')}</p></div>
      <button className="red-button" onClick={onSOS}>{t('Emergency controls')}</button>
    </div>
    <div className="console-metrics">
      <article><span>{t('Current country')}</span><strong>{country || t("Choose country")}</strong></article>
      <article><span>{t("Listed services")}</span><strong>{services.length}</strong></article>
      <article><span>{t('Trusted contacts')}</span><strong>{contacts}</strong></article>
      <article><span>{t("Browser connection")}</span><strong>{t(online ? 'Online' : 'Offline')}</strong></article>
    </div>
    <div className="console-grid">
      <article className="service-card">
        <h2>{t("Directory overview")}</h2>
        <table><thead><tr><th>{t("Service")}</th><th>{t("Coverage")}</th><th>{t("Channels")}</th></tr></thead>
          <tbody>{services.slice(0, 10).map(service => <tr key={service.id}>
            <td>{service.name}</td><td>{service.region || t("National")}</td>
            <td>{[...new Set(service.channels.map(channel => channel.kind))].join(', ')}</td>
          </tr>)}</tbody></table>
        {!services.length && <p>{t("Choose a country in the header to review its directory.")}</p>}
        <button onClick={() => onNavigate('All Helplines')}>{t('All Helplines')}</button>
      </article>
      <article className="service-card console-actions">
        <h2>{t("Safety workspace")}</h2>
        <button onClick={() => onNavigate('My Safety')}>{t('My Safety')}</button>
        <button onClick={() => onNavigate('AI Assistant')}>{t('AI Assistant')}</button>
        <button onClick={() => onNavigate('Settings')}>{t('Settings')}</button>
        <button onClick={() => onNavigate('Download')}>{t('Download')}</button>
        <a href="/mobile">{t("Open phone layout")}</a>
      </article>
    </div>
  </section>;
}
