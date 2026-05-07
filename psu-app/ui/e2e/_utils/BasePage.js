class BasePage {
  constructor(page) {
    this.page = page;
  }

  async goto(path) {
    await this.page.goto(path, { waitUntil: 'networkidle' });
    await this.waitForPSUReady();
  }

  async waitForSelector(selector, options = {}) {
    await this.page.waitForSelector(selector, {
      state: 'visible',
      timeout: 15000,
      ...options
    });
  }

  async getElement(selector) {
    await this.waitForSelector(selector);
    return this.page.locator(selector);
  }

  async click(selector) {
    await this.waitForSelector(selector);
    await this.page.click(selector);
  }

  async fill(selector, value) {
    await this.waitForSelector(selector);
    await this.page.fill(selector, value);
  }

  async getText(selector) {
    await this.waitForSelector(selector);
    return this.page.locator(selector).textContent();
  }

  async isElementVisible(selector) {
    return await this.page.locator(selector).isVisible();
  }

  async waitForNavigation() {
    await this.page.waitForLoadState('networkidle');
  }

  async waitForPSUReady() {
    // PSU server-side dynamic rendering shows a top-level MUI spinner during initial load.
    // Wait briefly for it to disappear, but don't block on content-level spinners
    // (e.g., the discovery status banner intentionally shows a spinner while a scan runs).
    const spinner = this.page.locator('.MuiCircularProgress-root');
    const spinnerCount = await spinner.count();
    if (spinnerCount > 0) {
      try {
        await spinner.first().waitFor({ state: 'hidden', timeout: 5000 });
      } catch {
        // Spinner is still visible after 5s — assume it's legitimate content, not a page loader.
      }
    }
  }

  async waitForElement(selector, timeout = 15000) {
    await this.page.locator(selector).waitFor({ state: 'visible', timeout });
  }

  async waitForToast(textContains) {
    // PSU uses iziToast, not MUI Snackbar
    const toast = this.page.locator(`.iziToast:has-text("${textContains}")`);
    await toast.waitFor({ state: 'visible', timeout: 15000 });
    return toast;
  }

  async selectMUIOption(selectId, optionValue) {
    // PSU MUI Select: hidden <input id="selectId"> + visible <div role="combobox">
    // Click the combobox div (not the hidden input) to open the dropdown
    const combobox = this.page.locator(`[role="combobox"][aria-labelledby="${selectId}label"]`);
    await combobox.waitFor({ state: 'visible', timeout: 15000 });
    await combobox.scrollIntoViewIfNeeded();
    await combobox.click();
    // Click the option by data-value attribute
    const option = this.page.locator(`[role="listbox"] [role="option"][data-value="${optionValue}"]`);
    await option.waitFor({ state: 'visible', timeout: 15000 });
    await option.click();
  }

  async getMUISelectValue(selectId) {
    // Read from the hidden input that holds the actual value
    return await this.page.locator(`#${selectId}`).inputValue();
  }

  async getDataGridLayoutMetrics(selector, gridIndex, requiredFields) {
    return await this.page.evaluate(({ selector, gridIndex, requiredFields }) => {
      const grids = Array.from(document.querySelectorAll(selector));
      if (gridIndex < 0 || gridIndex >= grids.length) {
        throw new Error(`Expected data grid index ${gridIndex}; found ${grids.length} grid(s).`);
      }

      const root = grids[gridIndex];
      const virtualScroller = root.querySelector('.MuiDataGrid-virtualScroller');
      if (!virtualScroller) {
        throw new Error('DataGrid virtual scroller was not rendered.');
      }

      const pagination = root.querySelector('.MuiTablePagination-root');
      if (!pagination) {
        throw new Error('DataGrid pagination was not rendered.');
      }

      const rootRect = root.getBoundingClientRect();
      const scrollerRect = virtualScroller.getBoundingClientRect();
      const paginationRect = pagination.getBoundingClientRect();
      const documentElement = document.documentElement;

      const fieldMetrics = requiredFields.map(field => {
        const header = root.querySelector(`.MuiDataGrid-columnHeader[data-field="${field}"]`);
        if (!header) {
          throw new Error(`Required DataGrid header '${field}' was not rendered.`);
        }

        const headerRect = header.getBoundingClientRect();
        const cell = root.querySelector(`.MuiDataGrid-cell[data-field="${field}"]`);
        const cellRect = cell ? cell.getBoundingClientRect() : null;
        return {
          field,
          headerText: header.textContent.trim(),
          header: {
            left: headerRect.left,
            right: headerRect.right,
            width: headerRect.width,
            visibleInGrid: headerRect.left >= rootRect.left && headerRect.right <= rootRect.right
          },
          cell: cellRect ? {
            left: cellRect.left,
            right: cellRect.right,
            width: cellRect.width,
            visibleInGrid: cellRect.left >= rootRect.left && cellRect.right <= rootRect.right
          } : null
        };
      });

      return {
        viewport: {
          width: window.innerWidth,
          height: window.innerHeight
        },
        document: {
          clientWidth: documentElement.clientWidth,
          scrollWidth: documentElement.scrollWidth,
          hasHorizontalOverflow: documentElement.scrollWidth > window.innerWidth + 1
        },
        grid: {
          left: rootRect.left,
          right: rootRect.right,
          width: rootRect.width
        },
        virtualScroller: {
          left: scrollerRect.left,
          right: scrollerRect.right,
          clientWidth: virtualScroller.clientWidth,
          scrollWidth: virtualScroller.scrollWidth,
          hasHorizontalOverflow: virtualScroller.scrollWidth > virtualScroller.clientWidth + 1
        },
        pagination: {
          top: paginationRect.top,
          bottom: paginationRect.bottom,
          width: paginationRect.width,
          visibleInViewport: paginationRect.top >= 0 && paginationRect.bottom <= window.innerHeight
        },
        fields: fieldMetrics
      };
    }, { selector, gridIndex, requiredFields });
  }
}

module.exports = BasePage;
