export default {
  defaultTemplateId: 'default',
  defaultAltTemplateId: 'defaultAlt',
  templates: {
    'default': '<span class="msg-author">{0}</span><span class="msg-sep">·</span><span class="msg-body">{1}</span>',
    'defaultAlt': '<span class="msg-body">{0}</span>',
    'print': '<pre>{0}</pre>',
    'example:important': '<span class="msg-body">^2{0}</span>',
  },
  fadeTimeout: 8000,
  suggestionLimit: 6,
  style: {
    background: 'transparent',
    width: '34vw',
    height: '24%',
    borderRadius: '0',
  },
};
