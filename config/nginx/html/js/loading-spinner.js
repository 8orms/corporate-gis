/**
 * Модуль для создания анимированного индикатора загрузки
 * 
 * Автор: GIS Team
 * Дата: 01.03.2025
 * Версия: 1.0
 */

/**
 * Создает и возвращает DOM-элемент с анимированным спиннером
 * @param {string} color - Цвет спиннера (CSS color)
 * @param {number} size - Размер спиннера в пикселях
 * @param {number} thickness - Толщина линии в пикселях
 * @returns {HTMLElement} DOM-элемент спиннера
 */
function createSpinner(color = '#3498db', size = 64, thickness = 5) {
    // Создаем контейнер для спиннера
    const spinner = document.createElement('div');
    spinner.className = 'loading-spinner';
    
    // Стили для контейнера
    spinner.style.display = 'inline-block';
    spinner.style.position = 'relative';
    spinner.style.width = `${size}px`;
    spinner.style.height = `${size}px`;
    
    // Создаем анимированный круг с помощью CSS
    const styleElement = document.createElement('style');
    styleElement.textContent = `
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .loading-spinner:after {
            content: '';
            display: block;
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            border-radius: 50%;
            border: ${thickness}px solid rgba(255, 255, 255, 0.3);
            border-top-color: ${color};
            animation: spin 1s linear infinite;
            box-sizing: border-box;
        }
    `;
    
    // Добавляем стили к контейнеру
    spinner.appendChild(styleElement);
    
    return spinner;
}

/**
 * Создает индикатор загрузки с текстом
 * @param {string} text - Текст под спиннером
 * @param {Object} options - Дополнительные опции
 * @param {string} options.color - Цвет спиннера
 * @param {number} options.size - Размер спиннера
 * @param {number} options.thickness - Толщина линии
 * @param {string} options.textColor - Цвет текста
 * @param {string} options.fontFamily - Шрифт текста
 * @returns {HTMLElement} Контейнер с индикатором и текстом
 */
function createLoadingIndicator(text, options = {}) {
    const {
        color = '#3498db',
        size = 64,
        thickness = 5,
        textColor = '#333',
        fontFamily = 'Arial, sans-serif'
    } = options;
    
    // Создаем контейнер
    const container = document.createElement('div');
    container.style.display = 'flex';
    container.style.flexDirection = 'column';
    container.style.alignItems = 'center';
    container.style.justifyContent = 'center';
    
    // Создаем спиннер
    const spinner = createSpinner(color, size, thickness);
    container.appendChild(spinner);
    
    // Добавляем текст, если он предоставлен
    if (text) {
        const textElement = document.createElement('div');
        textElement.style.marginTop = '10px';
        textElement.style.color = textColor;
        textElement.style.fontFamily = fontFamily;
        textElement.style.textAlign = 'center';
        textElement.textContent = text;
        container.appendChild(textElement);
    }
    
    return container;
}

/**
 * Создает индикатор загрузки и добавляет его в указанный элемент
 * @param {string|HTMLElement} targetElement - DOM-элемент или CSS-селектор для добавления индикатора
 * @param {string} text - Текст под спиннером
 * @param {Object} options - Дополнительные опции (цвет, размер и т.д.)
 * @returns {HTMLElement} Созданный индикатор загрузки
 */
function showLoadingIndicator(targetElement, text = 'Загрузка...', options = {}) {
    const target = typeof targetElement === 'string' ? 
        document.querySelector(targetElement) : targetElement;
    
    if (!target) {
        console.error('Целевой элемент не найден:', targetElement);
        return null;
    }
    
    // Очищаем целевой элемент, если нужно
    if (options.clearTarget) {
        target.innerHTML = '';
    }
    
    // Создаем индикатор
    const indicator = createLoadingIndicator(text, options);
    
    // Устанавливаем стили контейнера
    if (options.fullScreen) {
        indicator.style.position = 'fixed';
        indicator.style.top = '0';
        indicator.style.left = '0';
        indicator.style.width = '100%';
        indicator.style.height = '100%';
        indicator.style.backgroundColor = options.overlayColor || 'rgba(255, 255, 255, 0.7)';
        indicator.style.zIndex = options.zIndex || 9999;
    }
    
    // Добавляем индикатор в целевой элемент
    target.appendChild(indicator);
    
    return indicator;
}

/**
 * Удаляет индикатор загрузки
 * @param {HTMLElement} indicator - Элемент индикатора, созданный функцией showLoadingIndicator
 */
function removeLoadingIndicator(indicator) {
    if (indicator && indicator.parentNode) {
        indicator.parentNode.removeChild(indicator);
    }
}

// Экспортируем функции
window.createSpinner = createSpinner;
window.createLoadingIndicator = createLoadingIndicator;
window.showLoadingIndicator = showLoadingIndicator;
window.removeLoadingIndicator = removeLoadingIndicator; 