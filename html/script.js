window.addEventListener('message', function(event) {
    if (event.data.action === 'showID') {
        const data = event.data;
        const template = document.getElementById(data.type + '-template');
        if (template) {
            // Populate spans
            const spans = template.querySelectorAll('span');
            spans.forEach(span => {
                if (data[span.className]) {
                    span.textContent = data[span.className];
                }
            });

            // Photo
            const photoEl = template.querySelector('.photo');
            if (photoEl && data.photo) {
                photoEl.style.backgroundImage = `url(images/${data.photo})`;
                photoEl.classList.add('has-photo');
            }

            // Name split & signature (driver)
            if (data.type === 'driver') {
                drawSignature(template.querySelector('.signature'), data.signature);
            }

            // Quality
            template.classList.remove('poor', 'passable', 'perfect', 'real');
            template.classList.add(data.quality || 'real');

            template.classList.remove('hidden');
            document.getElementById('card-container').style.display = 'block';
        }
    }
});

// drawSignature same

// Close same