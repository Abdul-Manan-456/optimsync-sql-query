import fs from "fs/promises";
import path from "path";
import pg from "pg";
import ExcelJS from "exceljs";

const DATABASE_URL =
  "postgresql://optimsync:optimsyncdev@127.0.0.1:5432/optimusync";

const QUERIES_DIR = path.resolve("queries");

const TABS = [
  {
    file: "daily-count.sql",
    sheetName: "Daily Count",
    headerColor: "4472C4",
  },
  {
    file: "group-by-insurance.sql",
    sheetName: "Group By Insurance",
    headerColor: "548235",
  },
  {
    file: "group-by-providers.sql",
    sheetName: "Group By Providers",
    headerColor: "BF8F00",
  },
];

const HEADER_FONT = { bold: true, color: { argb: "FFFFFFFF" }, size: 12 };
const DATA_FONT = { size: 11 };
const THIN_BORDER = {
  top: { style: "thin" },
  left: { style: "thin" },
  right: { style: "thin" },
  bottom: { style: "thin" },
};

function formatHeader(raw) {
  return raw
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function autoColumnWidth(columns, rows) {
  return columns.map((col) => {
    const headerLen = col.header.length;
    const maxDataLen = rows.reduce((max, row) => {
      const val = row[col.key];
      const len = val != null ? String(val).length : 0;
      return Math.max(max, len);
    }, 0);
    return Math.max(headerLen, maxDataLen, 12) + 4;
  });
}

async function main() {
  const pool = new pg.Pool({ connectionString: DATABASE_URL });

  try {
    const workbook = new ExcelJS.Workbook();
    workbook.creator = "OptimuSync Report Generator";
    workbook.created = new Date();

    for (const tab of TABS) {
      const sqlPath = path.join(QUERIES_DIR, tab.file);
      const sql = await fs.readFile(sqlPath, "utf-8");

      console.log(`Running query: ${tab.file} ...`);
      const { rows, fields } = await pool.query(sql);
      console.log(`  -> ${rows.length} rows returned`);

      // Build columns from query result fields
      const columns = fields.map((f) => ({
        header: formatHeader(f.name),
        key: f.name,
      }));

      const worksheet = workbook.addWorksheet(tab.sheetName);
      worksheet.columns = columns;

      // Compute widths and apply
      const widths = autoColumnWidth(columns, rows);
      worksheet.columns.forEach((col, i) => {
        col.width = widths[i];
      });

      // Style header row
      const headerRow = worksheet.getRow(1);
      headerRow.height = 28;
      headerRow.eachCell((cell) => {
        cell.font = HEADER_FONT;
        cell.fill = {
          type: "pattern",
          pattern: "solid",
          fgColor: { argb: `FF${tab.headerColor}` },
        };
        cell.alignment = {
          vertical: "middle",
          horizontal: "center",
          indent: 1,
        };
        cell.border = THIN_BORDER;
      });

      // Add data rows
      for (const row of rows) {
        const dataRow = worksheet.addRow(row);
        dataRow.height = 22;
        dataRow.eachCell((cell) => {
          cell.font = DATA_FONT;
          cell.alignment = {
            vertical: "middle",
            horizontal: "left",
            indent: 1,
          };
          cell.border = THIN_BORDER;
        });
      }

      // Freeze header row
      worksheet.views = [{ state: "frozen", ySplit: 1 }];
    }

    const outputPath = path.resolve("report.xlsx");
    await workbook.xlsx.writeFile(outputPath);
    console.log(`\nReport saved to: ${outputPath}`);
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error("Error generating report:", err);
  process.exit(1);
});
