export default function Page() {
  return (
    <main
      style={{
        display: 'flex',
        minHeight: '100vh',
        flexDirection: 'column',
        justifyContent: 'space-between',
        background: '#fff',
        color: '#111',
        fontFamily: 'Arial, sans-serif',
      }}
    >
      <div style={{ flex: 1 }} />
      <footer
        style={{
          display: 'flex',
          flexWrap: 'wrap',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: '1rem',
          padding: '1.5rem clamp(1.25rem, 5vw, 4rem)',
          background: '#0a0a0a',
          color: '#fff',
        }}
      >
        <p style={{ margin: 0, fontWeight: 600 }}>NSSMBC</p>
        <a
          href="https://instagram.com/nss_mbc?cplk=b2l0ZnJvaW5icHd4"
          target="_blank"
          rel="noopener noreferrer"
          aria-label="Visit NSSMBC on Instagram"
          style={{ color: 'inherit', textUnderlineOffset: '4px' }}
        >
          instagram.com/nss_mbc
        </a>
      </footer>
    </main>
  )
}

