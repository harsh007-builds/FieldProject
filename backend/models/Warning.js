const mongoose = require('mongoose');

const warningSchema = new mongoose.Schema({
  buildingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Building',
    required: true
  },
  buildingName: {
    type: String,
    required: true
  },
  alertType: {
    type: String,
    enum: ['CRITICAL_SCORE', 'MISSED_COLLECTION', 'GENERAL'],
    required: true
  },
  message: {
    type: String,
    required: true
  },
  additionalNote: {
    type: String,
    default: ''
  },
  status: {
    type: String,
    enum: ['Unread', 'Read'],
    default: 'Unread'
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Warning', warningSchema);
