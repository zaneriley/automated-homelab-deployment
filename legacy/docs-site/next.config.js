// --- LEGACY — RETIRED Nextra docs site --- DO NOT EDIT ---
// Documents the pre-Mac-Studio fleet topology (NUC setup_nuc.yml,
// Cloudflare DNS, cloud-init flow). Last successful Vercel deploy:
// 2024-12-15. Site is frozen at this state. Moved here from docs/site/
// per ADR-0014. Not built or deployed; preserved only as forensic
// reference for the legacy NUC topology.

module.exports = {
      ...require("nextra")({
        theme: "nextra-theme-docs",
        themeConfig: "./theme.config.jsx",
        latex: true,
        titleSuffix:
        "Automated Homelab Deployment with Ansible and Terraform",
      })()
    };