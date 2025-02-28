/**
 * JavaScript для динамического отображения полей в зависимости от типа слоя
 */
document.addEventListener('DOMContentLoaded', function() {
    var typeField = document.getElementById('id_type');
    
    function toggleFieldsByType() {
        var selectedType = typeField.value;
        var fieldsets = document.querySelectorAll('fieldset');
        
        fieldsets.forEach(function(fieldset) {
            // Определяем тип fieldset по наличию классов
            var isRasterFields = fieldset.classList.contains('raster-fields');
            var isVectorFields = fieldset.classList.contains('vector-fields');
            
            if (isRasterFields) {
                // Показываем/скрываем поля для растрового слоя
                fieldset.style.display = (selectedType === 'raster') ? 'block' : 'none';
            } else if (isVectorFields) {
                // Показываем/скрываем поля для векторного слоя
                fieldset.style.display = (selectedType === 'vector') ? 'block' : 'none';
            }
        });
        
        // Также обрабатываем поля, которые могут быть скрыты через row-class
        var rows = document.querySelectorAll('.form-row');
        rows.forEach(function(row) {
            if (row.classList.contains('field-file_path')) {
                row.style.display = (selectedType === 'raster') ? 'block' : 'none';
            } else if (row.classList.contains('field-data_store') || row.classList.contains('field-table_name')) {
                row.style.display = (selectedType === 'vector') ? 'block' : 'none';
            }
        });
    }
    
    function handleTagsField() {
        // Обработка тегов в формате списка
        var tagsField = document.getElementById('id_tags');
        if (!tagsField || tagsField.tagName !== 'TEXTAREA') return;
        
        // Начальное преобразование JSON в текст
        try {
            var tagsValue = JSON.parse(tagsField.value || '[]');
            if (Array.isArray(tagsValue)) {
                tagsField.value = tagsValue.join(', ');
            }
        } catch (e) {
            // Если не удалось распарсить JSON, оставляем как есть
            console.warn('Не удалось преобразовать JSON-теги в текст:', e);
        }
        
        // При отправке формы преобразуем обратно в JSON
        var form = tagsField.form;
        form.addEventListener('submit', function() {
            try {
                var tagsText = tagsField.value || '';
                var tagsList = tagsText.split(',')
                    .map(function(tag) { return tag.trim(); })
                    .filter(function(tag) { return tag !== ''; });
                tagsField.value = JSON.stringify(tagsList);
            } catch (e) {
                console.error('Ошибка при преобразовании тегов в JSON:', e);
            }
        });
    }
    
    // Инициализация
    if (typeField) {
        // Изначальное отображение полей
        toggleFieldsByType();
        
        // Слушаем изменения выбранного типа
        typeField.addEventListener('change', toggleFieldsByType);
    }
    
    // Обработка поля с тегами
    handleTagsField();
}); 