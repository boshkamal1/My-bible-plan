function downloadBibleBackup(text, filename) {
        const url = URL.createObjectURL(new Blob([text], {type: 'application/json;charset=utf-8'}));
        const link = document.createElement('a');
        link.href = url;
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        link.remove();
        setTimeout(() => URL.revokeObjectURL(url), 60000);
      }
      function downloadProgressImage(data) {
        const link = document.createElement('a');
        link.href = data;
        link.download = 'bible-plan-progress.png';
        document.body.appendChild(link);
        link.click();
        link.remove();
      }
