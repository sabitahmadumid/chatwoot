<script>
import WidgetHead from './WidgetHead.vue';
import WidgetBody from './WidgetBody.vue';
import WidgetFooter from './WidgetFooter.vue';
import InputRadioGroup from 'dashboard/routes/dashboard/settings/inbox/components/InputRadioGroup.vue';
import globalConfigMixin from 'shared/mixins/globalConfigMixin';
import { mapGetters } from 'vuex';

export default {
  name: 'Widget',
  components: {
    WidgetHead,
    WidgetBody,
    WidgetFooter,
    InputRadioGroup,
  },
  mixins: [globalConfigMixin],
  props: {
    welcomeHeading: {
      type: String,
      default: '',
    },
    welcomeTagline: {
      type: String,
      default: '',
    },
    websiteName: {
      type: String,
      required: true,
    },
    logo: {
      type: String,
      default: '',
    },
    isOnline: {
      type: Boolean,
      default: true,
    },
    replyTime: {
      type: String,
      default: '',
    },
    color: {
      type: String,
      default: '',
    },
    widgetBubblePosition: {
      type: String,
      default: '',
    },
    widgetBubbleLauncherTitle: {
      type: String,
      default: '',
    },
    widgetBubbleType: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      widgetScreens: [
        {
          id: 'default',
          title: this.$t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_SCREEN.DEFAULT'),
          checked: true,
        },
        {
          id: 'chat',
          title: this.$t('INBOX_MGMT.WIDGET_BUILDER.WIDGET_SCREEN.CHAT'),
          checked: false,
        },
      ],
      isDefaultScreen: true,
      isWidgetVisible: true,
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    getWidgetConfig() {
      return {
        welcomeHeading: this.welcomeHeading,
        welcomeTagline: this.welcomeTagline,
        websiteName: this.websiteName,
        logo: this.logo,
        isDefaultScreen: this.isDefaultScreen,
        isOnline: this.isOnline,
        replyTime: this.replyTimeText,
        color: this.color,
      };
    },
    replyTimeText() {
      switch (this.replyTime) {
        case 'in_a_few_minutes':
          return this.$t(
            'INBOX_MGMT.WIDGET_BUILDER.REPLY_TIME.IN_A_FEW_MINUTES'
          );
        case 'in_a_day':
          return this.$t('INBOX_MGMT.WIDGET_BUILDER.REPLY_TIME.IN_A_DAY');
        default:
          return this.$t('INBOX_MGMT.WIDGET_BUILDER.REPLY_TIME.IN_A_FEW_HOURS');
      }
    },
    getBubblePositionStyle() {
      return {
        justifyContent: this.widgetBubblePosition === 'left' ? 'start' : 'end',
      };
    },
    isBubbleExpanded() {
      return (
        !this.isWidgetVisible && this.widgetBubbleType === 'expanded_bubble'
      );
    },
    getWidgetBubbleLauncherTitle() {
      return this.isWidgetVisible || this.widgetBubbleType === 'standard'
        ? ' '
        : this.widgetBubbleLauncherTitle;
    },
  },
  methods: {
    handleScreenChange(item) {
      this.isDefaultScreen = item.id === 'default';
    },
    toggleWidget() {
      this.isWidgetVisible = !this.isWidgetVisible;
      this.isDefaultScreen = true;
    },
  },
};
</script>

<template>
  <div>
    <div v-if="isWidgetVisible" class="flex flex-col items-center">
      <InputRadioGroup
        name="widget-screen"
        :items="widgetScreens"
        :action="handleScreenChange"
      />
    </div>
    <div
      v-if="isWidgetVisible"
      class="widget-wrapper flex flex-col justify-between rounded-lg shadow-md bg-n-slate-2 dark:bg-n-solid-1 h-[31.25rem] w-80"
    >
      <WidgetHead :config="getWidgetConfig" />
      <div>
        <WidgetBody
          v-if="!getWidgetConfig.isDefaultScreen"
          :config="getWidgetConfig"
        />
        <WidgetFooter :config="getWidgetConfig" />
      </div>
    </div>
    <div class="flex mt-4 w-[320px]" :style="getBubblePositionStyle">
      <button
        class="relative flex items-center justify-center rounded-full cursor-pointer"
        :style="{ background: color }"
        :class="
          isBubbleExpanded
            ? 'w-auto font-medium text-base text-white dark:text-white h-12 px-4'
            : 'w-16 h-16'
        "
        @click="toggleWidget"
      >
        <img
          v-if="!isWidgetVisible"
          src="~dashboard/assets/images/bubble-logo.svg"
          alt=""
          draggable="false"
          class="w-6 h-6 mx-auto"
        />
        <div v-if="isBubbleExpanded" class="ltr:pl-2.5 rtl:pr-2.5">
          {{ getWidgetBubbleLauncherTitle }}
        </div>
        <div v-if="isWidgetVisible" class="relative">
          <div class="absolute w-0.5 h-8 rotate-45 -translate-y-1/2 bg-white" />
          <div
            class="absolute w-0.5 h-8 -rotate-45 -translate-y-1/2 bg-white"
          />
        </div>
      </button>
    </div>
  </div>
</template>
