﻿using System;
using System.Collections.Generic;
using Realms;
using Xamarin.Forms;

namespace RealmTasks
{
    public class ItemColoringBehavior<T> : Behavior<View> where T : RealmObject
    {
        private IDisposable _notificationToken;
        private WeakReference<View> _view;

        public static BindableProperty RealmCollectionProperty = 
            BindableProperty.Create(nameof(RealmCollection), typeof(IList<T>), typeof(ItemColoringBehavior<T>), propertyChanged: OnRealmCollectionChanged);

        public IList<T> RealmCollection
        {
            get
            {
                return (IList<T>)GetValue(RealmCollectionProperty);
            }
            set
            {
                SetValue(RealmCollectionProperty, value);
            }
        }

        public Color[] Colors { get; set; }

        static void OnRealmCollectionChanged(BindableObject bindable, object oldValue, object newValue)
        {
            var self = (ItemColoringBehavior<T>)bindable;
            self._notificationToken?.Dispose();

            var newCollection = newValue as IRealmCollection<T>;
            self._notificationToken = newCollection?.SubscribeForNotifications(delegate { self.CalculateColor(); });
        }

        protected override void OnAttachedTo(View bindable)
        {
            base.OnAttachedTo(bindable);

            _view = new WeakReference<View>(bindable);
            CalculateColor();
        }

        protected override void OnDetachingFrom(View bindable)
        {
            base.OnDetachingFrom(bindable);

            _view = null;
            _notificationToken?.Dispose();
        }

        private void CalculateColor()
        {
            View view = null;
            if (RealmCollection != null && _view?.TryGetTarget(out view) == true)
            {
                var item = view.BindingContext as T;
                if (item != null)
                {
                    var index = RealmCollection.IndexOf(item);
                    var fraction = index / (double)Math.Max(13, RealmCollection.Count);
                    view.BackgroundColor = GradientColorAtFraction(fraction);
                }
            }
        }

        private Color GradientColorAtFraction(double fraction)
        {
            // Ensure offset is normalized to 1
            var normalizedOffset = Math.Max(Math.Min(fraction, 1), 0);

            // Work out the 'size' that each color stop spans
            var colorStopRange = 1.0 / (Colors.Length - 1);

            // Determine the base stop our offset is within
            var colorRangeIndex = (int)Math.Floor(normalizedOffset / colorStopRange);

            // Get the initial color which will serve as the origin
            var topColor = Colors[colorRangeIndex];
            var fromColors = new[] { topColor.R, topColor.G, topColor.B };
            // Get the destination color we will lerp to
            var bottomColor = Colors[colorRangeIndex + 1];
            var toColors = new[] { bottomColor.R, bottomColor.G, bottomColor.B };

            // Work out the actual percentage we need to lerp, inside just that stop range
            var stopOffset = (normalizedOffset - colorRangeIndex * colorStopRange) / colorStopRange;

            return new Color(
                fromColors[0] + stopOffset * (toColors[0] - fromColors[0]),
                fromColors[1] + stopOffset * (toColors[1] - fromColors[1]),
                fromColors[2] + stopOffset * (toColors[2] - fromColors[2]));
        }
    }
}
