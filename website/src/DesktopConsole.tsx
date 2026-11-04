type Service = {id:string; name:string; region?:string|null; channels:{kind:string;value:string}[]};

export function DesktopConsole({country, services, online, contacts, onSOS, onNavigate}: {
  country: string; services: Service[]; online: boolean; contacts: number;
  onSOS: () => void; onNavigate: (tab:string) => void;
}) {
  return <section className="desktop-console" aria-label="Desktop safety console">
    <div className="console-hero">
      <div><p className="eyebrow">DESKTOP SAFETY CONSOLE</p><h1>Global SOS</h1><p>Review services, prepare a check-in, and manage trusted contacts.</p></div>
      <button className="red-button" onClick={onSOS}>Open SOS controls</button>
    </div>
    <div className="console-metrics">
      <article><span>Country</span><strong>{country || 'Choose country'}</strong></article>
      <article><span>Listed services</span><strong>{services.length}</strong></article>
      <article><span>Trusted contacts</span><strong>{contacts}</strong></article>
      <article><span>Browser connection</span><strong>{online ? 'Online' : 'Offline'}</strong></article>
    </div>
    <div className="console-grid">
      <article className="service-card">
        <h2>Directory overview</h2>
        <table><thead><tr><th>Service</th><th>Coverage</th><th>Channels</th></tr></thead>
          <tbody>{services.slice(0, 10).map(service => <tr key={service.id}>
            <td>{service.name}</td><td>{service.region || 'National'}</td>
            <td>{[...new Set(service.channels.map(channel => channel.kind))].join(', ')}</td>
          </tr>)}</tbody></table>
        {!services.length && <p>Choose a country in the header to review its directory.</p>}
        <button onClick={() => onNavigate('All Helplines')}>Search full directory</button>
      </article>
      <article className="service-card console-actions">
        <h2>Safety workspace</h2>
        <button onClick={() => onNavigate('My Safety')}>Inbox, check-ins and sharing</button>
        <button onClick={() => onNavigate('AI Assistant')}>Find help with the assistant</button>
        <button onClick={() => onNavigate('Settings')}>Connection and setup checks</button>
        <button onClick={() => onNavigate('Download')}>Download Android APK</button>
        <a href="/mobile">Open phone layout</a>
      </article>
    </div>
  </section>;
}
