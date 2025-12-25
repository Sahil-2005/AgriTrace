import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { 
  Plus, 
  Package, 
  TrendingUp, 
  Users, 
  QrCode,
  Calendar,
  Truck,
  Award,
  Eye,
  Download,
  ArrowUpRight,
  ShoppingCart
} from 'lucide-react';
import { Link } from 'react-router-dom';

export const DistributorDashboard = () => {
  const { user, profile } = useAuth();
  const [stats, setStats] = useState({
    totalPurchases: 0,
    totalSales: 0,
    totalRevenue: 0,
    activeInventory: 0
  });
  const [recentTransactions, setRecentTransactions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (user) {
      fetchDashboardData();
    }
  }, [user]);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      
      console.log('🔍 DEBUG: Fetching dashboard data for user:', user?.id);
      
      // Get the distributor's profile ID first
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('id')
        .eq('user_id', user?.id)
        .single();

      if (profileError || !profile) {
        console.error('❌ Profile lookup error:', profileError);
        setStats({ totalPurchases: 0, totalSales: 0, totalRevenue: 0 });
        return;
      }

      console.log('🔍 DEBUG: Found profile ID:', profile.id);
      
      // Get distributor's purchases from transactions table (simplified query)
      const { data: purchases, error: purchasesError } = await supabase
        .from('transactions')
        .select('*')
        .eq('buyer_id', profile.id)
        .eq('transaction_type', 'PURCHASE')
        .order('created_at', { ascending: false });

      console.log('🔍 DEBUG: Purchases query result:', { purchases, purchasesError });
      console.log('🔍 DEBUG: User ID:', user?.id);

      // Debug: Check all transactions in the database
      const { data: allTransactions } = await supabase
        .from('transactions')
        .select('*')
        .limit(10);
      
      console.log('🔍 DEBUG: All transactions in database:', allTransactions);

      // Get batch details separately for each purchase
      let purchasesWithDetails = [];
      if (purchases && purchases.length > 0) {
        const batchIds = purchases.map(p => p.batch_id);
        const { data: batches } = await supabase
          .from('batches')
          .select('*')
          .in('id', batchIds);
        
        // Merge transaction and batch data
        purchasesWithDetails = purchases.map(purchase => {
          const batch = batches?.find(b => b.id === purchase.batch_id);
          return {
            ...purchase,
            batch: batch
          };
        });
      }

      console.log('🔍 DEBUG: Purchases with details:', purchasesWithDetails);

      // Get distributor's sales (batches they own that are available for sale)
      const { data: sales } = await supabase
        .from('batches')
        .select('*, profiles!batches_current_owner_fkey(*)')
        .eq('current_owner', profile.id)
        .eq('status', 'available');

      setStats({
        totalPurchases: purchasesWithDetails?.length || 0,
        totalSales: sales?.length || 0,
        totalRevenue: purchasesWithDetails?.reduce((sum, transaction) => sum + transaction.price, 0) || 0,
        activeInventory: sales?.length || 0
      });

      setRecentTransactions(purchasesWithDetails?.slice(0, 5) || []);
    } catch (error) {
      console.error('Error fetching distributor dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
          <p>Loading dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">
          Welcome back, {profile?.full_name || 'Distributor'}!
        </h1>
        <p className="text-gray-600">Manage your distribution business and track your supply chain.</p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Purchases</CardTitle>
            <ShoppingCart className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalPurchases}</div>
            <p className="text-xs text-muted-foreground">Batches purchased</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Sales</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalSales}</div>
            <p className="text-xs text-muted-foreground">Batches sold</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Revenue</CardTitle>
            <Award className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">₹{stats.totalRevenue.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">From sales</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Inventory</CardTitle>
            <Package className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.activeInventory}</div>
            <p className="text-xs text-muted-foreground">Available batches</p>
          </CardContent>
        </Card>
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Truck className="h-5 w-5" />
              Buy from Farmers
            </CardTitle>
            <CardDescription>
              Purchase fresh produce directly from farmers
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button asChild className="w-full">
              <Link to="/farmer-marketplace">
                <ShoppingCart className="h-4 w-4 mr-2" />
                Browse Farmer Marketplace
              </Link>
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Package className="h-5 w-5" />
              Sell to Retailers
            </CardTitle>
            <CardDescription>
              List your inventory for retailers to purchase
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button asChild className="w-full">
              <Link to="/distributor-inventory">
                <ArrowUpRight className="h-4 w-4 mr-2" />
                Manage Inventory
              </Link>
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Eye className="h-5 w-5" />
              Track Supply Chain
            </CardTitle>
            <CardDescription>
              Monitor your products through the supply chain
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button asChild variant="outline" className="w-full">
              <Link to="/track">
                <Eye className="h-4 w-4 mr-2" />
                Track Products
              </Link>
            </Button>
          </CardContent>
        </Card>
      </div>

      {/* Recent Transactions */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Transactions</CardTitle>
          <CardDescription>Your latest purchases and sales</CardDescription>
        </CardHeader>
        <CardContent>
          {recentTransactions.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <Package className="h-12 w-12 mx-auto mb-4 text-gray-300" />
              <p>No transactions yet</p>
              <p className="text-sm">Start by purchasing from farmers or selling to retailers</p>
            </div>
          ) : (
            <div className="space-y-4">
              {recentTransactions.map((transaction) => (
                <div key={transaction.id} className="flex items-center justify-between p-4 border rounded-lg">
                  <div className="flex items-center gap-4">
                    <div className="p-2 bg-primary/10 rounded-lg">
                      <Package className="h-5 w-5 text-primary" />
                    </div>
                    <div>
                      <h4 className="font-medium">{transaction.batch?.crop_type || 'Unknown Crop'} - {transaction.batch?.variety || 'Unknown Variety'}</h4>
                      <p className="text-sm text-gray-500">
                        From: {transaction.batch?.farmer_id || 'Unknown Farmer'} • {transaction.quantity} kg
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-medium">₹{transaction.price}</p>
                    <Badge variant="default">
                      {transaction.transaction_type}
                    </Badge>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
};
