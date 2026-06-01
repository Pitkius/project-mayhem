export default {
  defaultTemplateId: 'default', //This is the default template for 2 args1
  defaultAltTemplateId: 'defaultAlt', //This one for 1 arg
  templates: { //You can add static templates here
    'default': '<span class="msg-author">{0}</span><span class="msg-sep">:</span> <span class="msg-body">{1}</span>',
    'defaultAlt': '<span class="msg-body">{0}</span>',
    'print': '<pre>{0}</pre>',
    'example:important': '<h1>^2{0}</h1>'
  },
  fadeTimeout: 7000,
  suggestionLimit: 5,
  style: {
    background: 'rgba(15, 23, 42, 0.82)',
    width: '38vw',
    height: '22%',
    borderRadius: '10px',
  }
};
