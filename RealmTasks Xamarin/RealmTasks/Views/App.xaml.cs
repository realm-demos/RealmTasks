﻿using RealmTasks.Implementation;
using Xamarin.Forms;

namespace RealmTasks
{
    public partial class App : Application
    {
        public App()
        {
            InitializeComponent();

            var navigationService = DependencyService.Get<INavigationService>(DependencyFetchTarget.GlobalInstance);
            navigationService.SetMainPage<ListsViewModel>();
        }
    }
}
