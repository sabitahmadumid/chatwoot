import types from '../mutation-types';
import ConversationApi from '../../api/inbox/conversation';
import throttle from '@jcoreio/async-throttle';

const state = {
  mineCount: 0,
  unAssignedCount: 0,
  allCount: 0,
};

export const getters = {
  getStats: $state => $state,
};

const getMeta = async ({ commit }, params) => {
  try {
    const response = await ConversationApi.meta(params);
    const {
      data: { meta },
    } = response;
    commit(types.SET_CONV_TAB_META, meta);
  } catch (error) {
    // Ignore error
  }
};

const throttledGetMeta = throttle(getMeta, 5000);

export const actions = {
  get: async ({ commit, state: $state }, params) => {
    const fn = $state.allCount > 1000 ? throttledGetMeta : getMeta;
    return fn({ commit }, params);
  },
  set({ commit }, meta) {
    commit(types.SET_CONV_TAB_META, meta);
  },
};

export const mutations = {
  [types.SET_CONV_TAB_META](
    $state,
    {
      mine_count: mineCount,
      unassigned_count: unAssignedCount,
      all_count: allCount,
    } = {}
  ) {
    $state.mineCount = mineCount;
    $state.allCount = allCount;
    $state.unAssignedCount = unAssignedCount;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
